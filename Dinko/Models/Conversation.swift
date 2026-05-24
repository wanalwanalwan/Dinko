import Foundation

struct Conversation: Identifiable, Hashable, Codable {
    let id: UUID
    let playerId: UUID
    let coachId: UUID
    var lastMessageAt: Date?
    var lastMessagePreview: String?
    var playerUnreadCount: Int
    var coachUnreadCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case playerId = "player_id"
        case coachId = "coach_id"
        case lastMessageAt = "last_message_at"
        case lastMessagePreview = "last_message_preview"
        case playerUnreadCount = "player_unread_count"
        case coachUnreadCount = "coach_unread_count"
        case createdAt = "created_at"
    }
}
