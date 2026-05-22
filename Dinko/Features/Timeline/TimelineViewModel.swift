import Foundation

@MainActor
@Observable
final class TimelineViewModel {
    private(set) var sessions: [Session] = []
    private(set) var isLoading = false
    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var currentMonth: Date = Calendar.current.startOfDay(for: Date())
    private(set) var sessionDates: Set<Date> = []
    private(set) var skillNameMap: [UUID: String] = [:]

    var sessionsForSelectedDate: [Session] {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date > $1.date }
    }

    private let sessionRepository: SessionRepository
    private let skillRepository: SkillRepository

    init(sessionRepository: SessionRepository, skillRepository: SkillRepository) {
        self.sessionRepository = sessionRepository
        self.skillRepository = skillRepository
    }

    func loadSessions() async {
        isLoading = true
        do {
            let allSessions = try await sessionRepository.fetchAll()
            sessions = allSessions

            let calendar = Calendar.current
            sessionDates = Set(allSessions.map { calendar.startOfDay(for: $0.date) })

            let skills = try await skillRepository.fetchActive()
            let archived = try await skillRepository.fetchArchived()
            var map: [UUID: String] = [:]
            for skill in skills { map[skill.id] = skill.name }
            for skill in archived { map[skill.id] = skill.name }
            skillNameMap = map
        } catch {
            sessions = []
            sessionDates = []
        }
        isLoading = false
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
    }

    func changeMonth(by offset: Int) {
        guard let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: currentMonth) else { return }
        currentMonth = newMonth
    }

    func deleteSession(_ id: UUID) async {
        do {
            try await sessionRepository.delete(id)
            await loadSessions()
        } catch {
            // Non-critical
        }
    }

    // MARK: - Calendar Helpers

    func daysInMonthGrid() -> [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthRange = calendar.range(of: .day, in: .month, for: currentMonth) else {
            return []
        }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        // Sunday = 1, so offset = firstWeekday - 1
        let leadingBlanks = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for day in monthRange {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDay) {
                days.append(calendar.startOfDay(for: date))
            }
        }

        // Pad to fill last row (multiple of 7)
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    func monthYearString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    func hasSession(on date: Date) -> Bool {
        sessionDates.contains(Calendar.current.startOfDay(for: date))
    }

    func selectedDateDisplayString() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    func skillNames(for session: Session) -> [String] {
        session.skillIdArray.compactMap { skillNameMap[$0] }
    }
}
