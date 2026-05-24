import Foundation

/// Manages a WebSocket connection to Supabase Realtime for live coach_messages updates.
@Observable
@MainActor
final class RealtimeService {
    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var heartbeatRef = 0
    private var joinRef = 0
    private var isConnected = false
    private var subscribedConversationId: UUID?
    private var authToken: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    /// Called when a new message arrives via realtime
    var onMessageReceived: ((CoachChatMessage) -> Void)?

    /// Called when conversation metadata updates (unread counts, etc.)
    var onConversationUpdated: ((Conversation) -> Void)?

    // MARK: - Connect

    func connect(authToken: String) {
        self.authToken = authToken
        reconnectAttempts = 0
        establishConnection()
    }

    func disconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        subscribedConversationId = nil
    }

    // MARK: - Subscribe to a conversation

    func subscribe(toConversation conversationId: UUID) {
        subscribedConversationId = conversationId
        guard isConnected else { return }
        joinChannel(conversationId: conversationId)
    }

    func unsubscribe() {
        guard let conversationId = subscribedConversationId else { return }
        leaveChannel(conversationId: conversationId)
        subscribedConversationId = nil
    }

    // MARK: - Private: Connection

    private func establishConnection() {
        guard let token = authToken else { return }

        let urlString = "\(SupabaseConfig.realtimeURL)?apikey=\(SupabaseConfig.anonKey)&vsn=1.0.0"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        startReceiving()
        startHeartbeat()

        // Re-subscribe if we had an active subscription
        if let conversationId = subscribedConversationId {
            joinChannel(conversationId: conversationId)
        }
    }

    // MARK: - Private: Channel Join/Leave

    private func joinChannel(conversationId: UUID) {
        joinRef += 1
        let topic = "realtime:public:coach_messages:conversation_id=eq.\(conversationId.uuidString)"
        let payload: [String: Any] = [
            "event": "phx_join",
            "topic": topic,
            "payload": [
                "config": [
                    "postgres_changes": [
                        [
                            "event": "INSERT",
                            "schema": "public",
                            "table": "coach_messages",
                            "filter": "conversation_id=eq.\(conversationId.uuidString)",
                        ]
                    ]
                ]
            ],
            "ref": "\(joinRef)",
        ]
        send(payload)
    }

    private func leaveChannel(conversationId: UUID) {
        let topic = "realtime:public:coach_messages:conversation_id=eq.\(conversationId.uuidString)"
        let payload: [String: Any] = [
            "event": "phx_leave",
            "topic": topic,
            "payload": [:] as [String: Any],
            "ref": "\(joinRef + 1)",
        ]
        send(payload)
    }

    // MARK: - Private: Heartbeat

    private func startHeartbeat() {
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard !Task.isCancelled else { break }
                self?.sendHeartbeat()
            }
        }
    }

    private func sendHeartbeat() {
        heartbeatRef += 1
        let payload: [String: Any] = [
            "event": "heartbeat",
            "topic": "phoenix",
            "payload": [:] as [String: Any],
            "ref": "\(heartbeatRef)",
        ]
        send(payload)
    }

    // MARK: - Private: Send

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(string)) { error in
            if let error {
                #if DEBUG
                print("[RealtimeService] Send error: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Private: Receive

    private func startReceiving() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                guard let ws = self.webSocketTask else { break }
                do {
                    let message = try await ws.receive()
                    self.handleMessage(message)
                } catch {
                    #if DEBUG
                    print("[RealtimeService] Receive error: \(error.localizedDescription)")
                    #endif
                    if !Task.isCancelled {
                        self.handleDisconnect()
                    }
                    break
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        let event = json["event"] as? String ?? ""

        if event == "postgres_changes" || event == "INSERT" {
            handleInsertEvent(json)
        }
        // Also handle the nested payload format
        if let payload = json["payload"] as? [String: Any],
           let nestedData = payload["data"] as? [String: Any],
           let record = nestedData["record"] as? [String: Any] {
            parseAndDeliverMessage(record)
        }
    }

    private func handleInsertEvent(_ json: [String: Any]) {
        guard let payload = json["payload"] as? [String: Any] else { return }

        // Supabase Realtime v2 format
        if let record = payload["record"] as? [String: Any] {
            parseAndDeliverMessage(record)
            return
        }

        // Nested data format
        if let data = payload["data"] as? [String: Any],
           let record = data["record"] as? [String: Any] {
            parseAndDeliverMessage(record)
        }
    }

    private func parseAndDeliverMessage(_ record: [String: Any]) {
        guard let idString = record["id"] as? String,
              let id = UUID(uuidString: idString),
              let convString = record["conversation_id"] as? String,
              let conversationId = UUID(uuidString: convString),
              let senderString = record["sender_id"] as? String,
              let senderId = UUID(uuidString: senderString),
              let content = record["content"] as? String,
              let createdAtString = record["created_at"] as? String else { return }

        let createdAt = ISO8601DateFormatter.withFractionalSeconds.date(from: createdAtString)
            ?? ISO8601DateFormatter.standard.date(from: createdAtString)
            ?? Date()

        let message = CoachChatMessage(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            createdAt: createdAt,
            readAt: nil
        )

        onMessageReceived?(message)
    }

    // MARK: - Private: Reconnect

    private func handleDisconnect() {
        isConnected = false
        webSocketTask = nil

        guard reconnectAttempts < maxReconnectAttempts else {
            #if DEBUG
            print("[RealtimeService] Max reconnect attempts reached")
            #endif
            return
        }

        reconnectTask = Task { [weak self] in
            guard let self else { return }
            let delay = min(pow(2.0, Double(self.reconnectAttempts)), 30.0)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.reconnectAttempts += 1
            self.establishConnection()
        }
    }
}
