import Foundation

/// REST API service for coach chat — conversations, messages, profiles
final class CoachChatService {
    private let session = URLSession.shared
    private let baseURL = SupabaseConfig.url
    private let anonKey = SupabaseConfig.anonKey

    private lazy var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: str) {
                return date
            }
            if let date = ISO8601DateFormatter.standard.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(str)")
        }
        return d
    }()

    // MARK: - User Profile / Role

    struct UserProfile: Codable {
        let id: UUID
        let role: UserRole
        let displayName: String
        let coachBio: String?
        let coachSpecialties: [String]?

        enum CodingKeys: String, CodingKey {
            case id, role
            case displayName = "display_name"
            case coachBio = "coach_bio"
            case coachSpecialties = "coach_specialties"
        }
    }

    func fetchUserProfile(userId: UUID, authToken: String) async throws -> UserProfile? {
        let url = URL(string: "\(baseURL)/rest/v1/user_profiles?id=eq.\(userId.uuidString)&select=*")!
        let data = try await get(url: url, authToken: authToken)
        let profiles = try decoder.decode([UserProfile].self, from: data)
        return profiles.first
    }

    // MARK: - Conversations

    func fetchConversations(forUserId userId: UUID, role: UserRole, authToken: String) async throws -> [Conversation] {
        let filter = role == .coach ? "coach_id" : "player_id"
        let url = URL(string: "\(baseURL)/rest/v1/conversations?\(filter)=eq.\(userId.uuidString)&select=*&order=last_message_at.desc.nullslast")!
        let data = try await get(url: url, authToken: authToken)
        return try decoder.decode([Conversation].self, from: data)
    }

    func fetchConversation(playerId: UUID, authToken: String) async throws -> Conversation? {
        let url = URL(string: "\(baseURL)/rest/v1/conversations?player_id=eq.\(playerId.uuidString)&select=*&limit=1")!
        let data = try await get(url: url, authToken: authToken)
        let conversations = try decoder.decode([Conversation].self, from: data)
        return conversations.first
    }

    // MARK: - Messages

    func fetchMessages(conversationId: UUID, limit: Int = 50, before: Date? = nil, authToken: String) async throws -> [CoachChatMessage] {
        var urlString = "\(baseURL)/rest/v1/coach_messages?conversation_id=eq.\(conversationId.uuidString)&select=*&order=created_at.desc&limit=\(limit)"
        if let before {
            let formatted = ISO8601DateFormatter.withFractionalSeconds.string(from: before)
            urlString += "&created_at=lt.\(formatted)"
        }
        let url = URL(string: urlString)!
        let data = try await get(url: url, authToken: authToken)
        let messages = try decoder.decode([CoachChatMessage].self, from: data)
        return messages.reversed()
    }

    func sendMessage(conversationId: UUID, senderId: UUID, content: String, authToken: String) async throws -> CoachChatMessage {
        let url = URL(string: "\(baseURL)/rest/v1/coach_messages?select=*")!
        let body: [String: Any] = [
            "conversation_id": conversationId.uuidString,
            "sender_id": senderId.uuidString,
            "content": content,
        ]
        let data = try await post(url: url, body: body, authToken: authToken)
        let messages = try decoder.decode([CoachChatMessage].self, from: data)
        guard let message = messages.first else {
            throw CoachChatError.invalidResponse
        }
        return message
    }

    // MARK: - Mark Read

    func markMessagesRead(conversationId: UUID, readerId: UUID, authToken: String) async throws {
        // Mark all unread messages in this conversation that were NOT sent by the reader
        let url = URL(string: "\(baseURL)/rest/v1/coach_messages?conversation_id=eq.\(conversationId.uuidString)&sender_id=neq.\(readerId.uuidString)&read_at=is.null")!
        let body: [String: Any] = [
            "read_at": ISO8601DateFormatter.withFractionalSeconds.string(from: Date()),
        ]
        _ = try await patch(url: url, body: body, authToken: authToken)
    }

    func resetUnreadCount(conversationId: UUID, role: UserRole, authToken: String) async throws {
        let field = role == .player ? "player_unread_count" : "coach_unread_count"
        let url = URL(string: "\(baseURL)/rest/v1/conversations?id=eq.\(conversationId.uuidString)")!
        let body: [String: Any] = [field: 0]
        _ = try await patch(url: url, body: body, authToken: authToken)
    }

    // MARK: - Fetch partner name

    func fetchPartnerName(partnerId: UUID, authToken: String) async throws -> String {
        let profile = try await fetchUserProfile(userId: partnerId, authToken: authToken)
        return profile?.displayName ?? "Coach"
    }

    // MARK: - Private HTTP helpers

    private func get(url: URL, authToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func post(url: URL, body: [String: Any], authToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func patch(url: URL, body: [String: Any], authToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return data
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CoachChatError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                throw CoachChatError.unauthorized
            }
            throw CoachChatError.server("HTTP \(http.statusCode)")
        }
    }
}

// MARK: - Errors

enum CoachChatError: LocalizedError {
    case invalidResponse
    case unauthorized
    case server(String)
    case noConversation

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server"
        case .unauthorized: "Session expired. Please sign in again."
        case .server(let msg): msg
        case .noConversation: "No coach assigned yet."
        }
    }
}

// MARK: - ISO8601 Helpers

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static let standard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
