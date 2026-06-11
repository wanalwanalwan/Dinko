import Foundation

/// Computed summary of a pillar's progress toward the user's goal.
struct SkillPillarSummary: Identifiable {
    let pillar: SkillPillar
    let totalSkills: Int
    let skillsAtTarget: Int
    let totalGap: Int
    let largestGapSkill: String?
    let isCurrentFocus: Bool

    var id: String { pillar.rawValue }

    var remainingSkills: Int {
        totalSkills - skillsAtTarget
    }

    var isComplete: Bool {
        totalGap == 0
    }
}
