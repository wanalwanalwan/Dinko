import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    var duprRange: String?
    var playStyle: String?
    var gameFormat: String?
    var primaryGoal: String?
    var ageRange: String?
    var weeklyGoal: Int?
    var drillPreferences: Set<String> = []

    private let defaults = UserDefaults.standard

    init() {
        loadFromDefaults()
    }

    func loadFromDefaults() {
        duprRange = defaults.string(forKey: "pkkl_dupr_range")
        playStyle = defaults.string(forKey: "pkkl_play_style")
        gameFormat = defaults.string(forKey: "pkkl_game_format")
        primaryGoal = defaults.string(forKey: "pkkl_primary_goal")
        ageRange = defaults.string(forKey: "pkkl_age_range")
        let weekly = defaults.integer(forKey: "pkkl_weekly_goal")
        weeklyGoal = weekly > 0 ? weekly : nil
        if let prefs = defaults.stringArray(forKey: "pkkl_drill_preferences") {
            drillPreferences = Set(prefs)
        }
    }

    func save() {
        if let duprRange {
            defaults.set(duprRange, forKey: "pkkl_dupr_range")
        }
        if let playStyle {
            defaults.set(playStyle, forKey: "pkkl_play_style")
        }
        if let gameFormat {
            defaults.set(gameFormat, forKey: "pkkl_game_format")
        }
        if let primaryGoal {
            defaults.set(primaryGoal, forKey: "pkkl_primary_goal")
        }
        if let ageRange {
            defaults.set(ageRange, forKey: "pkkl_age_range")
        }
        if let weeklyGoal {
            defaults.set(weeklyGoal, forKey: "pkkl_weekly_goal")
        }
        if !drillPreferences.isEmpty {
            defaults.set(Array(drillPreferences), forKey: "pkkl_drill_preferences")
        }
    }

    var isProfileComplete: Bool {
        duprRange != nil &&
        playStyle != nil &&
        gameFormat != nil &&
        primaryGoal != nil &&
        ageRange != nil
    }
}
