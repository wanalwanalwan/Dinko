import Foundation

struct TimelineDayGroup: Identifiable {
    let id: Date
    let displayDate: String
    var entries: [JournalEntry]
}

@MainActor
@Observable
final class TimelineViewModel {
    private(set) var dayGroups: [TimelineDayGroup] = []
    private(set) var isLoading = false

    private let journalEntryRepository: JournalEntryRepository

    init(journalEntryRepository: JournalEntryRepository) {
        self.journalEntryRepository = journalEntryRepository
    }

    func loadEntries() async {
        isLoading = true
        do {
            let entries = try await journalEntryRepository.fetchAll()
            dayGroups = groupByDay(entries)
        } catch {
            dayGroups = []
        }
        isLoading = false
    }

    func deleteEntry(_ id: UUID) async {
        do {
            try await journalEntryRepository.delete(id)
            await loadEntries()
        } catch {
            // Non-critical
        }
    }

    private func groupByDay(_ entries: [JournalEntry]) -> [TimelineDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        return grouped.keys.sorted(by: >).map { dayStart in
            TimelineDayGroup(
                id: dayStart,
                displayDate: formatDayHeader(dayStart),
                entries: grouped[dayStart] ?? []
            )
        }
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date).uppercased()
        }
    }
}
