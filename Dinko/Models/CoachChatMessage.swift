import Foundation

struct CoachChatMessage: Identifiable, Hashable, Codable {
    let id: UUID
    let conversationId: UUID
    let senderId: UUID
    let content: String
    let createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}
