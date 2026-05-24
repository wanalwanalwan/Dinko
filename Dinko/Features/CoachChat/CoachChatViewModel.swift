import Foundation

@Observable
@MainActor
final class CoachChatViewModel {
    var messages: [CoachChatMessage] = []
    var inputText = ""
    var isSending = false
    var isLoading = true
    var error: String?
    var partnerName = "Coach"
    var hasMoreMessages = true

    private let chatService = CoachChatService()
    private let realtimeService: RealtimeService
    private let conversation: Conversation
    private let currentUserId: UUID
    private let role: UserRole

    init(conversation: Conversation, currentUserId: UUID, role: UserRole, realtimeService: RealtimeService) {
        self.conversation = conversation
        self.currentUserId = currentUserId
        self.role = role
        self.realtimeService = realtimeService
    }

    var conversationId: UUID { conversation.id }

    func loadInitial() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            error = "Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        do {
            messages = try await chatService.fetchMessages(conversationId: conversation.id, authToken: token)
            hasMoreMessages = messages.count >= 50

            // Fetch partner name
            let partnerId = role == .player ? conversation.coachId : conversation.playerId
            partnerName = try await chatService.fetchPartnerName(partnerId: partnerId, authToken: token)

            // Mark messages as read
            try await chatService.markMessagesRead(conversationId: conversation.id, readerId: currentUserId, authToken: token)
            try await chatService.resetUnreadCount(conversationId: conversation.id, role: role, authToken: token)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false

        // Subscribe to realtime
        realtimeService.onMessageReceived = { [weak self] message in
            guard let self, message.conversationId == self.conversation.id else { return }
            // Don't duplicate messages we sent ourselves
            if !self.messages.contains(where: { $0.id == message.id }) {
                self.messages.append(message)
                // Mark as read immediately since user is viewing
                Task { await self.markNewMessageRead() }
            }
        }
        realtimeService.subscribe(toConversation: conversation.id)
    }

    func loadMoreMessages() async {
        guard hasMoreMessages, let oldest = messages.first else { return }
        guard let token = await AuthService.shared.validAccessToken() else { return }

        do {
            let older = try await chatService.fetchMessages(
                conversationId: conversation.id,
                limit: 50,
                before: oldest.createdAt,
                authToken: token
            )
            hasMoreMessages = older.count >= 50
            messages.insert(contentsOf: older, at: 0)
        } catch {
            #if DEBUG
            print("[CoachChatVM] Load more error: \(error)")
            #endif
        }
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true

        Task {
            guard let token = await AuthService.shared.validAccessToken() else {
                error = "Please sign in again."
                isSending = false
                return
            }

            do {
                let message = try await chatService.sendMessage(
                    conversationId: conversation.id,
                    senderId: currentUserId,
                    content: text,
                    authToken: token
                )
                // Add locally (realtime will also deliver it, but we deduplicate)
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
            } catch {
                self.error = "Failed to send: \(error.localizedDescription)"
                // Put text back for retry
                inputText = text
            }
            isSending = false
        }
    }

    func cleanup() {
        realtimeService.unsubscribe()
        realtimeService.onMessageReceived = nil
    }

    private func markNewMessageRead() async {
        guard let token = await AuthService.shared.validAccessToken() else { return }
        try? await chatService.markMessagesRead(conversationId: conversation.id, readerId: currentUserId, authToken: token)
        try? await chatService.resetUnreadCount(conversationId: conversation.id, role: role, authToken: token)
    }
}
