import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let role: Role
    let content: Content
    let timestamp: Date

    enum Role {
        case user
        case agent
    }

    enum Content {
        case text(String)
        case loading
        case sessionPreview(SessionPreview)
        case error(String)
    }

    init(
        id: UUID = UUID(),
        role: Role,
        content: Content,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - Agent Response Types

struct SessionPreview {
    let sessionId: String
    let extraction: ExtractionData
    let skillUpdates: [SkillUpdate]
    let drillRecommendations: [DrillRecommendation]
    let roadmapUpdates: RoadmapUpdates?
    let subskillSuggestions: [SubskillSuggestion]?
    let skillSuggestions: [SkillCreationSuggestion]?
    var confirmState: ConfirmState = .pending

    enum ConfirmState {
        case pending
        case confirming
        case confirmed
        case failed(String)
    }
}

struct SubskillSuggestion: Codable {
    let name: String
    let description: String
    let suggestedRating: Int
    let parentSkillId: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case suggestedRating = "suggested_rating"
        case parentSkillId = "parent_skill_id"
    }
}

struct SkillCreationSuggestion: Codable {
    let name: String
    let category: String
    let description: String
    let suggestedRating: Int
    let iconName: String

    enum CodingKeys: String, CodingKey {
        case name, category, description
        case suggestedRating = "suggested_rating"
        case iconName = "icon_name"
    }
}

struct ExtractionData: Codable {
    let mentions: [Mention]
    let newSkillSuggestions: [String]
    let sessionDurationMinutes: Int?
    let sessionType: String?

    enum CodingKeys: String, CodingKey {
        case mentions
        case newSkillSuggestions = "new_skill_suggestions"
        case sessionDurationMinutes = "session_duration_minutes"
        case sessionType = "session_type"
    }
}

struct Mention: Codable {
    let skillName: String
    let sentiment: String
    let intensity: Int
    let subskillsMentioned: [String]
    let quote: String

    enum CodingKeys: String, CodingKey {
        case skillName = "skill_name"
        case sentiment
        case intensity
        case subskillsMentioned = "subskills_mentioned"
        case quote
    }
}

struct SkillUpdate: Codable {
    let skillId: String
    let skill: String
    let old: Int
    let new: Int
    let delta: Int
    let subskillDeltas: [SubskillDelta]

    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case skill
        case old, new, delta
        case subskillDeltas = "subskill_deltas"
    }
}

struct SubskillDelta: Codable {
    let name: String
    let old: Int
    let new: Int
    let delta: Int
}

struct DrillRecommendation: Codable {
    let name: String
    let description: String
    let targetSkill: String
    let targetSubskill: String?
    let durationMinutes: Int
    let playerCount: Int?
    let equipment: String?
    let reason: String
    let priority: String

    enum CodingKeys: String, CodingKey {
        case name, description
        case targetSkill = "target_skill"
        case targetSubskill = "target_subskill"
        case durationMinutes = "duration_minutes"
        case playerCount = "player_count"
        case equipment, reason, priority
    }
}

struct RoadmapUpdates: Codable {
    let weeklyFocus: RoadmapEntry?
    let milestones: [RoadmapEntry]

    enum CodingKeys: String, CodingKey {
        case weeklyFocus = "weekly_focus"
        case milestones
    }
}

struct RoadmapEntry: Codable {
    let type: String
    let title: String
    let description: String
    let targetSkill: String?
    let targetValue: Int?
    let status: String
    let startsAt: String
    let endsAt: String?

    enum CodingKeys: String, CodingKey {
        case type, title, description
        case targetSkill = "target_skill"
        case targetValue = "target_value"
        case status
        case startsAt = "starts_at"
        case endsAt = "ends_at"
    }
}
