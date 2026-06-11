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
    case mastery
    case journey
}

enum AchievementType: String, CaseIterable, Codable {
    // Consistency — streak & session milestones
    case firstSession       // Logged first session
    case threePeat          // 3-day streak
    case perfectWeek        // Hit weekly session goal
    case ironStreak         // 14-day streak
    case unbreakable        // 30-day streak

    // Mastery — confidence-based milestones
    case firstCheckmark     // First skill at target confidence
    case pillarComplete     // All skills in a pillar at target
    case allAround          // Skills at target across 3+ pillars
    case bottleneckBreaker  // Improved bottleneck skill by 2+ in a week
    case firstUnlock        // Unlocked a previously locked skill
    case fullCycle          // Completed Learn+Practice+Apply+Play for one skill

    // Journey — goal DUPR milestones
    case roadTo35           // Set 3.5 as goal and reached all targets
    case roadTo40           // Set 4.0 as goal and reached all targets
    case roadTo45           // Set 4.5 as goal and reached all targets
    case roadTo50           // Set 5.0 as goal and reached all targets
    case chapterComplete    // All skills at target for current goal

    var achievement: Achievement {
        switch self {
        // Consistency
        case .firstSession:
            Achievement(id: self, name: "First Rally", description: "Logged your first session", iconName: "figure.pickleball", color: AppColors.achievementBlue, category: .consistency)
        case .threePeat:
            Achievement(id: self, name: "Three-Peat", description: "3-day activity streak", iconName: "flame.fill", color: AppColors.warningOrange, category: .consistency)
        case .perfectWeek:
            Achievement(id: self, name: "Perfect Week", description: "Hit your weekly session goal", iconName: "target", color: AppColors.successGreen, category: .consistency)
        case .ironStreak:
            Achievement(id: self, name: "Iron Streak", description: "14-day activity streak", iconName: "bolt.fill", color: AppColors.coral, category: .consistency)
        case .unbreakable:
            Achievement(id: self, name: "Unbreakable", description: "30-day activity streak", iconName: "bolt.shield.fill", color: AppColors.trophyGold, category: .consistency)

        // Mastery
        case .firstCheckmark:
            Achievement(id: self, name: "First Checkmark", description: "First skill reached target confidence", iconName: "checkmark.seal.fill", color: AppColors.successGreen, category: .mastery)
        case .pillarComplete:
            Achievement(id: self, name: "Pillar Complete", description: "Every skill in a pillar at target", iconName: "star.fill", color: AppColors.tierGold, category: .mastery)
        case .allAround:
            Achievement(id: self, name: "All-Around", description: "Skills at target across 3+ pillars", iconName: "circle.hexagongrid.fill", color: AppColors.primary, category: .mastery)
        case .bottleneckBreaker:
            Achievement(id: self, name: "Bottleneck Breaker", description: "Improved a bottleneck skill by 2+ in a week", iconName: "chart.line.uptrend.xyaxis", color: AppColors.coral, category: .mastery)
        case .firstUnlock:
            Achievement(id: self, name: "First Unlock", description: "Met prerequisites to unlock a skill", iconName: "lock.open.fill", color: AppColors.achievementPink, category: .mastery)
        case .fullCycle:
            Achievement(id: self, name: "Full Cycle", description: "Completed Learn-Practice-Apply-Play for a skill", iconName: "arrow.triangle.2.circlepath", color: AppColors.drillPurple, category: .mastery)

        // Journey
        case .roadTo35:
            Achievement(id: self, name: "Road to 3.5", description: "All skills at 3.5 DUPR targets", iconName: "flag.fill", color: AppColors.tierBlue, category: .journey)
        case .roadTo40:
            Achievement(id: self, name: "Road to 4.0", description: "All skills at 4.0 DUPR targets", iconName: "flag.fill", color: AppColors.primary, category: .journey)
        case .roadTo45:
            Achievement(id: self, name: "Road to 4.5", description: "All skills at 4.5 DUPR targets", iconName: "flag.fill", color: AppColors.tierGold, category: .journey)
        case .roadTo50:
            Achievement(id: self, name: "Road to 5.0", description: "All skills at 5.0 DUPR targets", iconName: "trophy.fill", color: AppColors.trophyGold, category: .journey)
        case .chapterComplete:
            Achievement(id: self, name: "Chapter Complete", description: "Reached all targets for your goal DUPR", iconName: "book.closed.fill", color: AppColors.trophyGold, category: .journey)
        }
    }
}
