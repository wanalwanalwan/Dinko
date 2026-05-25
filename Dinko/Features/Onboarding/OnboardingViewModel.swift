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
    var drillPreferences: Set<String> = []

    func completeOnboarding() {
        persistPreferences()
    }

    // MARK: - Private Helpers

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
        if !drillPreferences.isEmpty {
            UserDefaults.standard.set(Array(drillPreferences), forKey: "pkkl_drill_preferences")
        }
    }

}
