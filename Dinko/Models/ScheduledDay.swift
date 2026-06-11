import Foundation

/// A single day in a weekly training plan.
struct ScheduledDay: Identifiable, Hashable {
    let id: UUID
    let dayOfWeek: Int // 1 = Monday, 7 = Sunday
    let sessionType: SessionType
    var isCompleted: Bool
    var mission: String?

    init(
        id: UUID = UUID(),
        dayOfWeek: Int,
        sessionType: SessionType,
        isCompleted: Bool = false,
        mission: String? = nil
    ) {
        self.id = id
        self.dayOfWeek = dayOfWeek
        self.sessionType = sessionType
        self.isCompleted = isCompleted
        self.mission = mission
    }

    var dayAbbreviation: String {
        switch dayOfWeek {
        case 1: return "Mon"
        case 2: return "Tue"
        case 3: return "Wed"
        case 4: return "Thu"
        case 5: return "Fri"
        case 6: return "Sat"
        case 7: return "Sun"
        default: return "?"
        }
    }
}

/// A complete weekly training plan.
struct WeekPlan: Identifiable {
    let id: UUID
    var days: [ScheduledDay]
    let weekStartDate: Date

    init(
        id: UUID = UUID(),
        days: [ScheduledDay],
        weekStartDate: Date = Date()
    ) {
        self.id = id
        self.days = days
        self.weekStartDate = weekStartDate
    }

    var completedDays: Int {
        days.filter(\.isCompleted).count
    }

    var totalTrainingDays: Int {
        days.filter { $0.sessionType != .rest }.count
    }
}
