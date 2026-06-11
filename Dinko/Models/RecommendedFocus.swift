import Foundation

/// Output of the recommendation engine: what the user should work on today.
struct RecommendedFocus: Identifiable {
    let id: UUID
    let skill: Skill
    let pillar: SkillPillar
    let sessionType: SessionType
    let currentConfidence: Int
    let targetConfidence: Int
    let gap: Int
    let reason: String

    init(
        id: UUID = UUID(),
        skill: Skill,
        pillar: SkillPillar,
        sessionType: SessionType,
        currentConfidence: Int,
        targetConfidence: Int,
        reason: String
    ) {
        self.id = id
        self.skill = skill
        self.pillar = pillar
        self.sessionType = sessionType
        self.currentConfidence = currentConfidence
        self.targetConfidence = targetConfidence
        self.gap = targetConfidence - currentConfidence
        self.reason = reason
    }
}
