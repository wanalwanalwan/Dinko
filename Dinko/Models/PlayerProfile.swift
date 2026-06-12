import Foundation

struct PlayerProfile {
    let duprRange: String?
    let playStyle: String?
    let gameFormat: String?
    let primaryGoal: String?
    let ageRange: String?
    let weeklyGoal: Int?
    let practiceSetting: String?
    let experienceLevel: String?
    let injuries: [String]?
    let drillPreferences: [String]?
    let drillBalance: String?

    static func current() -> PlayerProfile {
        let defaults = UserDefaults.standard
        let weeklyGoalRaw = defaults.integer(forKey: "pkkl_weekly_goal")
        return PlayerProfile(
            duprRange: defaults.string(forKey: "pkkl_dupr_range"),
            playStyle: defaults.string(forKey: "pkkl_play_style"),
            gameFormat: defaults.string(forKey: "pkkl_game_format"),
            primaryGoal: defaults.string(forKey: "pkkl_primary_goal"),
            ageRange: defaults.string(forKey: "pkkl_age_range"),
            weeklyGoal: weeklyGoalRaw > 0 ? weeklyGoalRaw : nil,
            practiceSetting: defaults.string(forKey: "pkkl_practice_setting"),
            experienceLevel: defaults.string(forKey: "pkkl_experience_level"),
            injuries: defaults.stringArray(forKey: "pkkl_injuries"),
            drillPreferences: defaults.stringArray(forKey: "pkkl_drill_preferences"),
            drillBalance: defaults.string(forKey: "pkkl_drill_balance")
        )
    }

    func toPayload() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let duprRange { dict["dupr_range"] = duprRange }
        if let playStyle { dict["play_style"] = playStyle }
        if let gameFormat { dict["game_format"] = gameFormat }
        if let primaryGoal { dict["primary_goal"] = primaryGoal }
        if let ageRange { dict["age_range"] = ageRange }
        if let weeklyGoal { dict["weekly_goal"] = weeklyGoal }
        if let practiceSetting { dict["practice_setting"] = practiceSetting }
        if let experienceLevel { dict["experience_level"] = experienceLevel }
        if let injuries, !injuries.isEmpty {
            dict["injuries"] = injuries
        }
        if let drillPreferences, !drillPreferences.isEmpty {
            dict["drill_preferences"] = drillPreferences
        }
        if let drillBalance {
            dict["drill_balance"] = drillBalance
        }
        return dict
    }

    var isComplete: Bool {
        duprRange != nil &&
        playStyle != nil &&
        gameFormat != nil &&
        primaryGoal != nil &&
        ageRange != nil
    }
}
