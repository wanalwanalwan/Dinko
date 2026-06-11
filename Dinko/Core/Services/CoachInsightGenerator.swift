import Foundation

/// Stateless template-based coach insight generator.
/// Produces a single sentence based on the user's current state.
final class CoachInsightGenerator {

    struct Context {
        let pillarSummaries: [SkillPillarSummary]
        let bottleneckPillar: SkillPillar?
        let bottleneckSkillName: String?
        let skillsAtTarget: Int
        let totalSkills: Int
        let streakDays: Int
        let completedThisWeek: Int
        let weeklyGoal: Int
        let recentHistory: [FocusHistoryEntry]
    }

    static func generate(context: Context) -> String {
        // Priority order: celebrate streaks, weekly progress, bottleneck guidance, general encouragement

        // 1. Streak celebration
        if context.streakDays >= 30 {
            return "30+ day streak — you're building an unbreakable habit. Your consistency is your biggest edge."
        }
        if context.streakDays >= 14 {
            return "Two weeks straight! At this pace, improvement is inevitable."
        }
        if context.streakDays >= 7 {
            return "A full week of training. This kind of consistency separates good players from great ones."
        }

        // 2. Goal proximity
        if context.totalSkills > 0 {
            let pct = Double(context.skillsAtTarget) / Double(context.totalSkills)
            if pct >= 1.0 {
                return "All skills at target! Time to raise the bar — consider setting a higher DUPR goal."
            }
            if pct >= 0.8 {
                return "You're \(context.skillsAtTarget)/\(context.totalSkills) at target. The finish line is in sight."
            }
            if pct >= 0.5 {
                return "Past the halfway mark! Your hard work is showing in the numbers."
            }
        }

        // 3. Weekly goal progress
        if context.weeklyGoal > 0 {
            let remaining = context.weeklyGoal - context.completedThisWeek
            if remaining <= 0 {
                return "Weekly goal hit! Every extra session is bonus growth."
            }
            if remaining == 1 {
                return "One more session to hit your weekly goal. You've got this."
            }
        }

        // 4. Bottleneck guidance
        if let pillar = context.bottleneckPillar, let skill = context.bottleneckSkillName {
            let pillarSkills = context.pillarSummaries.first { $0.pillar == pillar }
            if let summary = pillarSkills, summary.totalGap > 5 {
                return "Your \(pillar.displayName) game has room to grow. \(skill) is the best place to start."
            }
            return "Focus on \(skill) today — it's the fastest path to closing your \(pillar.displayName) gap."
        }

        // 5. Recent activity feedback
        let recentCompleted = context.recentHistory.filter { $0.wasCompleted }.prefix(5)
        if recentCompleted.isEmpty {
            return "Welcome back! Even a short session today moves you forward."
        }

        let uniquePillars = Set(recentCompleted.map(\.pillar))
        if uniquePillars.count >= 3 {
            return "Great variety this week — working across \(uniquePillars.count) pillars builds a well-rounded game."
        }

        // 6. Streak start
        if context.streakDays >= 3 {
            return "\(context.streakDays)-day streak going! Don't break the chain."
        }

        return "Every session counts. Small improvements compound over time."
    }
}
