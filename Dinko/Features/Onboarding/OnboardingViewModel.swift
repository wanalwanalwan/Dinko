import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var duprRange: String?
    var playStyle: String?
    var gameFormat: String?
    var primaryGoal: String?
    var experienceLevel: String?
    var availableDays: Set<Int> = []  // 0=Mon..6=Sun
    var preferredGameDay: Int?
    var sessionDuration: Int?         // minutes: 30, 45, 60, 90
    var injuries: Set<String> = []
    var drillBalance: String?
    var drillPreferences: Set<String> = []
    var partnerAccess: String?
    var targetTimeline: String?
    var struggleAreas: Set<String> = []
    var pendingFocusSkills: [PendingFocusSkill] = []

    var trainingDaysPerWeek: Int { availableDays.count }

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
        if let experience = experienceLevel {
            UserDefaults.standard.set(experience, forKey: "pkkl_experience_level")
        }
        if !availableDays.isEmpty {
            UserDefaults.standard.set(Array(availableDays).sorted(), forKey: "pkkl_available_days")
            UserDefaults.standard.set(availableDays.count, forKey: "pkkl_weekly_goal")
        }
        if let gameDay = preferredGameDay {
            UserDefaults.standard.set(gameDay, forKey: "pkkl_preferred_game_day")
        }
        if let duration = sessionDuration {
            UserDefaults.standard.set(duration, forKey: "pkkl_session_duration")
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
        if let partner = partnerAccess {
            UserDefaults.standard.set(partner, forKey: "pkkl_partner_access")
        }
        if let timeline = targetTimeline {
            UserDefaults.standard.set(timeline, forKey: "pkkl_target_timeline")
        }
        if !struggleAreas.isEmpty {
            UserDefaults.standard.set(Array(struggleAreas), forKey: "pkkl_struggle_areas")
        }
    }

}
