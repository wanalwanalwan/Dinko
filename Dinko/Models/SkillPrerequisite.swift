import Foundation

/// Prerequisite rules for locked skills.
/// A skill is locked until all prerequisite skills reach their required confidence.
struct SkillPrerequisite {
    let skillCanonicalId: String
    let requiredSkillCanonicalId: String
    let requiredConfidence: Int // 1-10

    /// All prerequisite rules.
    static let all: [SkillPrerequisite] = [
        // ATP requires Court Positioning >= 6
        SkillPrerequisite(
            skillCanonicalId: "atp",
            requiredSkillCanonicalId: "court_positioning",
            requiredConfidence: 6
        ),
        // Erne requires Dinks >= 7 and Court Positioning >= 6
        SkillPrerequisite(
            skillCanonicalId: "erne",
            requiredSkillCanonicalId: "dink_rallies",
            requiredConfidence: 7
        ),
        SkillPrerequisite(
            skillCanonicalId: "erne",
            requiredSkillCanonicalId: "court_positioning",
            requiredConfidence: 6
        ),
        // Point Construction requires Pattern Play >= 6 and Stacking >= 5
        SkillPrerequisite(
            skillCanonicalId: "point_construction",
            requiredSkillCanonicalId: "pattern_play",
            requiredConfidence: 6
        ),
        SkillPrerequisite(
            skillCanonicalId: "point_construction",
            requiredSkillCanonicalId: "stacking",
            requiredConfidence: 5
        ),
    ]

    /// Get prerequisites for a given canonical skill ID.
    static func prerequisites(for canonicalId: String) -> [SkillPrerequisite] {
        all.filter { $0.skillCanonicalId == canonicalId }
    }

    /// Check if a skill is locked given current confidence levels.
    /// Returns true if ANY prerequisite is not met.
    static func isLocked(
        canonicalId: String,
        confidences: [String: Int] // canonicalId -> current confidence
    ) -> Bool {
        let prereqs = prerequisites(for: canonicalId)
        guard !prereqs.isEmpty else { return false }
        return prereqs.contains { prereq in
            let current = confidences[prereq.requiredSkillCanonicalId] ?? 0
            return current < prereq.requiredConfidence
        }
    }

    /// Get unmet prerequisites for a skill.
    static func unmetPrerequisites(
        for canonicalId: String,
        confidences: [String: Int]
    ) -> [SkillPrerequisite] {
        prerequisites(for: canonicalId).filter { prereq in
            let current = confidences[prereq.requiredSkillCanonicalId] ?? 0
            return current < prereq.requiredConfidence
        }
    }
}
