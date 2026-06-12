import Foundation

@MainActor
@Observable
final class ProfileViewModel {
    var duprRange: String?
    var playStyle: String?
    var gameFormat: String?
    var primaryGoal: String?
    var experienceLevel: String?
    var availableDays: Set<Int> = []  // 0=Mon..6=Sun
    var preferredGameDay: Int?
    var sessionDuration: Int?
    var injuries: Set<String> = []
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
        experienceLevel = defaults.string(forKey: "pkkl_experience_level")
        if let stored = defaults.array(forKey: "pkkl_available_days") as? [Int] {
            availableDays = Set(stored)
        }
        if defaults.object(forKey: "pkkl_preferred_game_day") != nil {
            preferredGameDay = defaults.integer(forKey: "pkkl_preferred_game_day")
        }
        let dur = defaults.integer(forKey: "pkkl_session_duration")
        sessionDuration = dur > 0 ? dur : nil
        if let inj = defaults.stringArray(forKey: "pkkl_injuries") {
            injuries = Set(inj)
        }
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
        if let experienceLevel {
            defaults.set(experienceLevel, forKey: "pkkl_experience_level")
        }
        if !availableDays.isEmpty {
            defaults.set(Array(availableDays).sorted(), forKey: "pkkl_available_days")
            defaults.set(availableDays.count, forKey: "pkkl_weekly_goal")
        } else {
            defaults.removeObject(forKey: "pkkl_available_days")
        }
        if let gameDay = preferredGameDay {
            defaults.set(gameDay, forKey: "pkkl_preferred_game_day")
        } else {
            defaults.removeObject(forKey: "pkkl_preferred_game_day")
        }
        if let duration = sessionDuration {
            defaults.set(duration, forKey: "pkkl_session_duration")
        } else {
            defaults.removeObject(forKey: "pkkl_session_duration")
        }
        if !injuries.isEmpty {
            defaults.set(Array(injuries), forKey: "pkkl_injuries")
        } else {
            defaults.removeObject(forKey: "pkkl_injuries")
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
        (defaults.string(forKey: "pkkl_age_range") != nil || !availableDays.isEmpty)
    }
}
