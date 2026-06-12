import SwiftUI

// MARK: - Achievement Definition

struct Achievement: Identifiable, Equatable {
    let id: AchievementType
    let name: String
    let description: String
    let iconName: String
    let color: Color
    let category: AchievementCategory

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
}

enum AchievementCategory: String {
    case consistency
    case progress
    case volume
    case improvement
}

enum AchievementType: String, CaseIterable, Codable {
    // Consistency — streak milestones
    case streak3        // 3-day streak
    case streak7        // 7-day streak
    case streak14       // 14-day streak
    case streak30       // 30-day streak
    case weeklyGoal     // Hit weekly session goal

    // Progress — tier milestones
    case firstSkill     // Added first skill
    case reachDeveloping // Average reached Developing tier
    case reachSolid     // Average reached Solid tier
    case reachAdvanced  // Average reached Advanced tier
    case reachWeapon    // Average reached Weapon tier
    case skillMastered  // Completed a skill (100%)

    // Volume — session count milestones
    case session1       // Logged first session
    case session5       // 5 sessions
    case session10      // 10 sessions
    case session25      // 25 sessions
    case session50      // 50 sessions

    // Improvement — growth milestones
    case bigWeek        // A skill improved 10+ in one week
    case allAbove50     // All active skills above 50%
    case firstDrill     // Completed first drill

    var achievement: Achievement {
        switch self {
        // Consistency
        case .streak3:
            Achievement(id: self, name: "On Fire", description: "3-day activity streak", iconName: "flame.fill", color: AppColors.warningOrange, category: .consistency)
        case .streak7:
            Achievement(id: self, name: "Week Warrior", description: "7-day activity streak", iconName: "flame.fill", color: AppColors.coral, category: .consistency)
        case .streak14:
            Achievement(id: self, name: "Unstoppable", description: "14-day activity streak", iconName: "bolt.fill", color: AppColors.coral, category: .consistency)
        case .streak30:
            Achievement(id: self, name: "Iron Will", description: "30-day activity streak", iconName: "bolt.shield.fill", color: AppColors.trophyGold, category: .consistency)
        case .weeklyGoal:
            Achievement(id: self, name: "Goal Crusher", description: "Hit your weekly session goal", iconName: "target", color: AppColors.successGreen, category: .consistency)

        // Progress
        case .firstSkill:
            Achievement(id: self, name: "Getting Started", description: "Added your first skill", iconName: "star.fill", color: AppColors.achievementPink, category: .progress)
        case .reachDeveloping:
            Achievement(id: self, name: "Developing", description: "Average rating hit Developing tier", iconName: "arrow.up.right", color: AppColors.tierBlue, category: .progress)
        case .reachSolid:
            Achievement(id: self, name: "Solid Player", description: "Average rating hit Solid tier", iconName: "checkmark.seal.fill", color: AppColors.primary, category: .progress)
        case .reachAdvanced:
            Achievement(id: self, name: "Advanced", description: "Average rating hit Advanced tier", iconName: "star.fill", color: AppColors.tierGold, category: .progress)
        case .reachWeapon:
            Achievement(id: self, name: "Weapon", description: "Average rating hit Weapon tier", iconName: "bolt.shield.fill", color: AppColors.coral, category: .progress)
        case .skillMastered:
            Achievement(id: self, name: "Mastery", description: "Completed a skill at 100%", iconName: "trophy.fill", color: AppColors.trophyGold, category: .progress)

        // Volume
        case .session1:
            Achievement(id: self, name: "First Rally", description: "Logged your first session", iconName: "figure.pickleball", color: AppColors.achievementBlue, category: .volume)
        case .session5:
            Achievement(id: self, name: "Regular", description: "Logged 5 sessions", iconName: "figure.pickleball", color: AppColors.achievementBlue, category: .volume)
        case .session10:
            Achievement(id: self, name: "Dedicated", description: "Logged 10 sessions", iconName: "medal.fill", color: AppColors.achievementYellow, category: .volume)
        case .session25:
            Achievement(id: self, name: "Committed", description: "Logged 25 sessions", iconName: "medal.fill", color: AppColors.tierGold, category: .volume)
        case .session50:
            Achievement(id: self, name: "Court Veteran", description: "Logged 50 sessions", iconName: "trophy.fill", color: AppColors.trophyGold, category: .volume)

        // Improvement
        case .bigWeek:
            Achievement(id: self, name: "Breakout Week", description: "A skill improved 10+ pts in one week", iconName: "chart.line.uptrend.xyaxis", color: AppColors.successGreen, category: .improvement)
        case .allAbove50:
            Achievement(id: self, name: "Well Rounded", description: "All active skills above 50%", iconName: "circle.hexagongrid.fill", color: AppColors.primary, category: .improvement)
        case .firstDrill:
            Achievement(id: self, name: "Drill Time", description: "Completed your first drill", iconName: "list.bullet.clipboard.fill", color: AppColors.drillPurple, category: .improvement)
        }
    }
}
