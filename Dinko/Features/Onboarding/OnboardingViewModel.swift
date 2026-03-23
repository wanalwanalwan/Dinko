import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    var duprRange: String?
    var trainingDaysPerWeek: Int?
    var drillPreferences: Set<String> = []

    func completeOnboarding() {
        persistPreferences()
    }

    // MARK: - Private Helpers

    private func persistPreferences() {
        if let days = trainingDaysPerWeek {
            UserDefaults.standard.set(days, forKey: "pkkl_weekly_goal")
        }
        if !drillPreferences.isEmpty {
            UserDefaults.standard.set(Array(drillPreferences), forKey: "pkkl_drill_preferences")
        }
    }

}
