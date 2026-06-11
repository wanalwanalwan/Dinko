import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var goalDUPR: String?
    var duprRange: String?
    var playStyle: String?
    var gameFormat: String?
    var primaryGoal: String?
    var trainingDaysPerWeek: Int?
    var practiceSetting: String?
    var experienceLevel: String?
    var injuries: Set<String> = []
    var drillBalance: String?
    var drillPreferences: Set<String> = []
    var pillarConfidences: [SkillPillar: Double] = [
        .consistency: 5, .transition: 4, .attack: 3, .movement: 4, .strategy: 3
    ]
    var pendingFocusSkills: [PendingFocusSkill] = []
    var isSeeding = false

    func completeOnboarding() async {
        persistPreferences()
        savePendingFocusSkills()

        // Save goal DUPR
        if let goal = goalDUPR {
            PlayerProfile.saveGoalDUPR(goal)
        }

        // Save pillar confidences
        var confidences: [String: Int] = [:]
        for (pillar, value) in pillarConfidences {
            confidences[pillar.rawValue] = Int(value)
        }
        PlayerProfile.savePillarConfidences(confidences)

        // Seed canonical skills from pillar confidences
        isSeeding = true
        await DataMigrationService.seedCanonicalSkills(
            pillarConfidences: confidences,
            persistence: PersistenceController.shared
        )
        isSeeding = false
    }

    // MARK: - Private Helpers

    private func savePendingFocusSkills() {
        guard !pendingFocusSkills.isEmpty else { return }
        if let data = try? JSONEncoder().encode(pendingFocusSkills) {
            UserDefaults.standard.set(data, forKey: FocusSkillManager.pendingKey)
        }
    }

    private func persistPreferences() {
        if let dupr = duprRange {
            UserDefaults.standard.set(dupr, forKey: "pkkl_dupr_range")
        }
        if let style = playStyle {
            UserDefaults.standard.set(style, forKey: "pkkl_play_style")
        }
        if let format = gameFormat {
            UserDefaults.standard.set(format, forKey: "pkkl_game_format")
        }
        if let goal = primaryGoal {
            UserDefaults.standard.set(goal, forKey: "pkkl_primary_goal")
        }
        if let days = trainingDaysPerWeek {
            UserDefaults.standard.set(days, forKey: "pkkl_weekly_goal")
        }
        if let setting = practiceSetting {
            UserDefaults.standard.set(setting, forKey: "pkkl_practice_setting")
        }
        if let experience = experienceLevel {
            UserDefaults.standard.set(experience, forKey: "pkkl_experience_level")
        }
        if !injuries.isEmpty {
            UserDefaults.standard.set(Array(injuries), forKey: "pkkl_injuries")
        }
        if let balance = drillBalance {
            UserDefaults.standard.set(balance, forKey: "pkkl_drill_balance")
        }
        if !drillPreferences.isEmpty {
            UserDefaults.standard.set(Array(drillPreferences), forKey: "pkkl_drill_preferences")
        }
    }

}
