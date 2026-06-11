import Foundation

/// A suggestion to update a skill's confidence after completing a learning cycle.
struct ConfidenceSuggestion: Identifiable {
    let id: UUID
    let skillId: UUID
    let skillName: String
    let currentConfidence: Int
    let suggestedConfidence: Int
    let evidence: [String]

    init(
        id: UUID = UUID(),
        skillId: UUID,
        skillName: String,
        currentConfidence: Int,
        suggestedConfidence: Int,
        evidence: [String]
    ) {
        self.id = id
        self.skillId = skillId
        self.skillName = skillName
        self.currentConfidence = currentConfidence
        self.suggestedConfidence = suggestedConfidence
        self.evidence = evidence
    }
}

/// After a user completes a full Learn -> Practice -> Apply -> Play cycle for a skill,
/// suggests a confidence bump with evidence.
final class MilestoneSuggestionEngine {

    /// Check if any skill has completed a full cycle and generate a suggestion.
    static func checkForSuggestion(
        skills: [Skill],
        confidences: [UUID: Int],
        history: [FocusHistoryEntry]
    ) -> ConfidenceSuggestion? {
        for skill in skills {
            guard skill.status == .active else { continue }

            let skillHistory = history
                .filter { $0.skillId == skill.id && $0.wasCompleted }
                .sorted { $0.date > $1.date }

            guard let suggestion = checkCycleCompletion(
                skill: skill,
                currentConfidence: confidences[skill.id] ?? 1,
                history: skillHistory
            ) else { continue }

            return suggestion
        }
        return nil
    }

    /// Check if a skill has a completed Learn -> Practice -> Apply -> Play cycle
    /// in the recent history (since last confidence update).
    private static func checkCycleCompletion(
        skill: Skill,
        currentConfidence: Int,
        history: [FocusHistoryEntry]
    ) -> ConfidenceSuggestion? {
        // Look for the cycle pattern in recent history (most recent first)
        let requiredTypes: Set<SessionType> = [.learn, .practice, .apply, .play]
        var foundTypes: Set<SessionType> = []
        var evidence: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short

        for entry in history.prefix(20) {
            guard requiredTypes.contains(entry.sessionType) else { continue }

            if !foundTypes.contains(entry.sessionType) {
                foundTypes.insert(entry.sessionType)
                let dateStr = dateFormatter.string(from: entry.date)
                evidence.append("Completed \(entry.sessionType.displayName) on \(dateStr)")
            }

            if foundTypes == requiredTypes {
                // Full cycle found
                let suggestedBump = min(currentConfidence + 1, 10)

                guard suggestedBump > currentConfidence else { return nil }

                return ConfidenceSuggestion(
                    skillId: skill.id,
                    skillName: skill.name,
                    currentConfidence: currentConfidence,
                    suggestedConfidence: suggestedBump,
                    evidence: evidence
                )
            }
        }

        return nil
    }
}
