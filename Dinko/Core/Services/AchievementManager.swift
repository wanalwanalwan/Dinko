import Foundation

/// Evaluates achievement criteria against current app data and persists unlocks to UserDefaults.
/// Stateless — call `evaluate(context:)` whenever data changes; it returns newly unlocked badges.
enum AchievementManager {
    private static let unlockedKey = "pkkl_achievements_unlocked"

    /// All unlocked achievement type IDs
    static var unlockedIds: Set<AchievementType> {
        guard let raw = UserDefaults.standard.stringArray(forKey: unlockedKey) else { return [] }
        return Set(raw.compactMap { AchievementType(rawValue: $0) })
    }

    /// Context needed to evaluate achievements — gathered from HomeViewModel / repositories
    struct Context {
        let streakDays: Int
        let weeklyGoalMet: Bool
        let totalActiveSkills: Int
        let averageRating: Int
        let completedSkillCount: Int
        let totalSessionsAllTime: Int
        let weeklySkillMovers: [(delta: Int, currentRating: Int)]
        let skillRatings: [Int] // all active skill ratings
        let totalDrillsCompleted: Int
    }

    /// Evaluate all achievement criteria. Returns newly unlocked achievements (empty if none).
    @discardableResult
    static func evaluate(context: Context) -> [Achievement] {
        var unlocked = unlockedIds
        var newlyUnlocked: [Achievement] = []

        func check(_ type: AchievementType, condition: Bool) {
            guard condition, !unlocked.contains(type) else { return }
            unlocked.insert(type)
            newlyUnlocked.append(type.achievement)
        }

        // Consistency
        check(.streak3,    condition: context.streakDays >= 3)
        check(.streak7,    condition: context.streakDays >= 7)
        check(.streak14,   condition: context.streakDays >= 14)
        check(.streak30,   condition: context.streakDays >= 30)
        check(.weeklyGoal, condition: context.weeklyGoalMet)

        // Progress
        check(.firstSkill,      condition: context.totalActiveSkills >= 1)
        check(.reachDeveloping,  condition: context.averageRating >= 21)
        check(.reachSolid,       condition: context.averageRating >= 41)
        check(.reachAdvanced,    condition: context.averageRating >= 61)
        check(.reachWeapon,      condition: context.averageRating >= 81)
        check(.skillMastered,    condition: context.completedSkillCount >= 1)

        // Volume
        check(.session1,  condition: context.totalSessionsAllTime >= 1)
        check(.session5,  condition: context.totalSessionsAllTime >= 5)
        check(.session10, condition: context.totalSessionsAllTime >= 10)
        check(.session25, condition: context.totalSessionsAllTime >= 25)
        check(.session50, condition: context.totalSessionsAllTime >= 50)

        // Improvement
        check(.bigWeek, condition: context.weeklySkillMovers.contains { $0.delta >= 10 })
        check(.firstDrill, condition: context.totalDrillsCompleted >= 1)

        if !context.skillRatings.isEmpty && context.skillRatings.allSatisfy({ $0 > 50 }) {
            check(.allAbove50, condition: true)
        }

        // Persist
        let rawIds = unlocked.map(\.rawValue)
        UserDefaults.standard.set(rawIds, forKey: unlockedKey)

        return newlyUnlocked
    }

    /// Ordered list of all achievements with their unlock status
    static func allAchievements() -> [(achievement: Achievement, isUnlocked: Bool)] {
        let unlocked = unlockedIds
        return AchievementType.allCases.map { type in
            (type.achievement, unlocked.contains(type))
        }
    }
}
