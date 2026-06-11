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

    /// Context needed to evaluate achievements — gathered from TodayViewModel / repositories
    struct Context {
        let streakDays: Int
        let weeklyGoalMet: Bool
        let totalSessionsAllTime: Int
        let skillsAtTarget: Int
        let totalTrackableSkills: Int
        let pillarsFullyAtTarget: Int      // number of pillars where all skills are at target
        let pillarsWithAnyAtTarget: Int    // number of pillars with at least one skill at target
        let goalDUPR: String?
        let allSkillsAtTarget: Bool
        let hasUnlockedSkill: Bool         // any previously locked skill now meets prereqs
        let hasCompletedCycle: Bool        // completed Learn+Practice+Apply+Play for one skill
        let bottleneckImprovedBy2: Bool    // improved a skill by 2+ in a week
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
        check(.firstSession,  condition: context.totalSessionsAllTime >= 1)
        check(.threePeat,     condition: context.streakDays >= 3)
        check(.perfectWeek,   condition: context.weeklyGoalMet)
        check(.ironStreak,    condition: context.streakDays >= 14)
        check(.unbreakable,   condition: context.streakDays >= 30)

        // Mastery
        check(.firstCheckmark,     condition: context.skillsAtTarget >= 1)
        check(.pillarComplete,     condition: context.pillarsFullyAtTarget >= 1)
        check(.allAround,          condition: context.pillarsWithAnyAtTarget >= 3)
        check(.bottleneckBreaker,  condition: context.bottleneckImprovedBy2)
        check(.firstUnlock,        condition: context.hasUnlockedSkill)
        check(.fullCycle,          condition: context.hasCompletedCycle)

        // Journey
        if context.allSkillsAtTarget, let goal = context.goalDUPR {
            check(.chapterComplete, condition: true)
            switch goal {
            case "3.5": check(.roadTo35, condition: true)
            case "4.0": check(.roadTo40, condition: true)
            case "4.5": check(.roadTo45, condition: true)
            case "5.0": check(.roadTo50, condition: true)
            default: break
            }
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
