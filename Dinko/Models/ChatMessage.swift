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
        case skillDeletion(SkillDeletionPreview)
        case skillCreation(SkillCreationPreview)
        case clarification(ClarificationPreview)
        case drillSuggestions(DrillSuggestionsPreview)
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

struct SaturatedSkillInfo: Equatable {
    let skillName: String
    let pendingCount: Int
}

struct SessionPreview {
    let sessionId: String
    let extraction: ExtractionData
    let coachInsight: String?
    let skillUpdates: [SkillUpdate]
    let drillRecommendations: [DrillRecommendation]
    let roadmapUpdates: RoadmapUpdates?
    let subskillSuggestions: [SubskillSuggestion]?
    let skillSuggestions: [SkillCreationSuggestion]?
    let saturatedSkills: [SaturatedSkillInfo]
    var confirmState: ConfirmState = .pending
    var selectedDrillIndices: Set<Int>
    var selectedSkillUpdateIndices: Set<Int>
    var selectedSubskillIndices: [Int: Set<Int>]

    enum ConfirmState: Equatable {
        case pending
        case confirming
        case confirmed
        case failed(String)
    }

    init(
        sessionId: String,
        extraction: ExtractionData,
        coachInsight: String? = nil,
        skillUpdates: [SkillUpdate],
        drillRecommendations: [DrillRecommendation],
        roadmapUpdates: RoadmapUpdates?,
        subskillSuggestions: [SubskillSuggestion]?,
        skillSuggestions: [SkillCreationSuggestion]?,
        saturatedSkills: [SaturatedSkillInfo] = [],
        confirmState: ConfirmState = .pending
    ) {
        self.sessionId = sessionId
        self.extraction = extraction
        self.coachInsight = coachInsight
        self.skillUpdates = skillUpdates
        self.drillRecommendations = drillRecommendations
        self.roadmapUpdates = roadmapUpdates
        self.subskillSuggestions = subskillSuggestions
        self.skillSuggestions = skillSuggestions
        self.saturatedSkills = saturatedSkills
        self.confirmState = confirmState
        self.selectedDrillIndices = Set<Int>()
        self.selectedSkillUpdateIndices = Set(skillUpdates.indices)

        var subIndices: [Int: Set<Int>] = [:]
        for (i, update) in skillUpdates.enumerated() {
            if !update.subskillDeltas.isEmpty {
                subIndices[i] = Set(update.subskillDeltas.indices)
            }
        }
        self.selectedSubskillIndices = subIndices
    }

    /// Computes the effective parent skill delta and new rating based on selected subskills.
    /// When all subskills are selected, returns original API values.
    /// When some are deselected, recalculates as average of selected subskill deltas.
    func effectiveSkillValues(for index: Int) -> (delta: Double, new: Int) {
        let update = skillUpdates[index]
        guard !update.subskillDeltas.isEmpty,
              let selectedSubs = selectedSubskillIndices[index],
              selectedSubs.count < update.subskillDeltas.count else {
            return (Double(update.delta), update.new)
        }

        let totalSubskills = update.subskillDeltas.count
        let selectedSum = update.subskillDeltas.enumerated()
            .filter { selectedSubs.contains($0.offset) }
            .reduce(0) { $0 + $1.element.delta }

        let avgDelta = Double(selectedSum) / Double(totalSubskills)
        let newRating = min(100, max(0, update.old + Int(round(avgDelta))))
        return (avgDelta, newRating)
    }
}

struct SkillDeletionPreview {
    let skillId: UUID
    let skillName: String
    let subskillNames: [String]
    var confirmState: ConfirmState

    enum ConfirmState: Equatable {
        case pending
        case confirming
        case confirmed
        case failed(String)
    }
}

struct SkillCreationPreview {
    let skillName: String
    var category: SkillCategory
    var confirmState: ConfirmState

    enum ConfirmState: Equatable {
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

// MARK: - Clarification

struct ClarificationPreview {
    let question: String
    let options: [ClarificationOption]
    let originalNote: String
    var state: ClarificationState

    enum ClarificationState: Equatable {
        case pending
        case selected(String) // selected option id
        case resolved
    }
}

struct ClarificationOption: Identifiable {
    let id: String
    let label: String
    let action: String
    let payloadJSON: Data?
}

// MARK: - Standalone Drill Suggestions

struct DrillSuggestionsPreview {
    let chatText: String
    let drills: [DrillRecommendation]
    var addedDrillIndices: Set<Int>
}
