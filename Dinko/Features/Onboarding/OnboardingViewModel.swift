import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var duprRange: String?
    var playStyle: String?
    var gameFormat: String?
    var primaryGoal: String?
    var ageRange: String?
    var trainingDaysPerWeek: Int?
    var practiceSetting: String?
    var partnerAvailability: String?
    var experienceLevel: String?
    var injuries: Set<String> = []
    var drillBalance: String?
    var drillPreferences: Set<String> = []
    var pendingFocusSkills: [PendingFocusSkill] = []

    func completeOnboarding() {
        persistPreferences()
        savePendingFocusSkills()
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
        if let age = ageRange {
            UserDefaults.standard.set(age, forKey: "pkkl_age_range")
        }
        if let days = trainingDaysPerWeek {
            UserDefaults.standard.set(days, forKey: "pkkl_weekly_goal")
        }
        if let setting = practiceSetting {
            UserDefaults.standard.set(setting, forKey: "pkkl_practice_setting")
        }
        if let partner = partnerAvailability {
            UserDefaults.standard.set(partner, forKey: "pkkl_partner_availability")
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
