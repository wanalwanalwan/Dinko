import Foundation

/// Generates weekly training plans with intelligent rest placement
/// and session type cycling (Learn -> Practice -> Apply -> Play).
final class SchedulingEngine {

    /// Generate a week plan based on training frequency.
    /// Rest days are distributed evenly, with at least 1 rest day after 3 consecutive training days.
    static func generateWeekPlan(
        weeklyGoal: Int,
        focusSkillName: String? = nil,
        weekStartDate: Date? = nil
    ) -> WeekPlan {
        let startDate = weekStartDate ?? currentWeekStart()
        let trainingDays = min(max(weeklyGoal, 1), 7)

        let trainingSlots = distributeTrainingDays(count: trainingDays)
        let cycle: [SessionType] = [.learn, .practice, .apply, .play]
        var trainingIndex = 0

        var days: [ScheduledDay] = []
        for dayOfWeek in 1...7 {
            if trainingSlots.contains(dayOfWeek) {
                let sessionType = cycle[trainingIndex % cycle.count]
                let mission: String?
                if sessionType == .play, let skill = focusSkillName {
                    mission = "Play with intention: focus on \(skill)"
                } else {
                    mission = nil
                }
                days.append(ScheduledDay(
                    dayOfWeek: dayOfWeek,
                    sessionType: sessionType,
                    mission: mission
                ))
                trainingIndex += 1
            } else {
                days.append(ScheduledDay(
                    dayOfWeek: dayOfWeek,
                    sessionType: .rest
                ))
            }
        }

        return WeekPlan(days: days, weekStartDate: startDate)
    }

    /// Distribute N training days across a 7-day week with intelligent rest placement.
    private static func distributeTrainingDays(count: Int) -> Set<Int> {
        switch count {
        case 1: return [2]                          // Tuesday
        case 2: return [2, 5]                       // Tue, Fri
        case 3: return [1, 3, 5]                    // Mon, Wed, Fri
        case 4: return [1, 2, 4, 6]                 // Mon, Tue, Thu, Sat
        case 5: return [1, 2, 3, 5, 6]              // Mon-Wed, Fri-Sat
        case 6: return [1, 2, 3, 4, 5, 6]           // Mon-Sat
        case 7: return [1, 2, 3, 4, 5, 6, 7]        // Every day
        default: return [1, 3, 5]                    // Default to 3
        }
    }

    /// Mark completed days in a plan based on session history.
    static func markCompletedDays(
        plan: WeekPlan,
        sessions: [Session]
    ) -> WeekPlan {
        var updatedPlan = plan
        let calendar = Calendar.current

        for i in updatedPlan.days.indices {
            let dayDate = calendar.date(
                byAdding: .day,
                value: updatedPlan.days[i].dayOfWeek - 1,
                to: plan.weekStartDate
            ) ?? Date()

            let hasSession = sessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: dayDate)
            }
            updatedPlan.days[i].isCompleted = hasSession
        }

        return updatedPlan
    }

    /// Get the start of the current week (Monday).
    static func currentWeekStart() -> Date {
        let calendar = Calendar.current
        var cal = calendar
        cal.firstWeekday = 2 // Monday
        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return cal.date(from: components) ?? Date()
    }

    /// Get today's day of week as 1-7 (Mon-Sun).
    static func todayDayOfWeek() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Convert from Sunday=1 to Monday=1
        return weekday == 1 ? 7 : weekday - 1
    }

    /// Get the session type for today from a week plan.
    static func todaySessionType(from plan: WeekPlan) -> SessionType? {
        let today = todayDayOfWeek()
        return plan.days.first { $0.dayOfWeek == today }?.sessionType
    }
}
