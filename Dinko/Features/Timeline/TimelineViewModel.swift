import Foundation

struct TimelineDayGroup: Identifiable {
    let id: Date
    let displayDate: String
    var entries: [JournalEntry]
}

// MARK: - Skill Update Row Model

struct SkillUpdateRow: Hashable {
    let skill: String
    let oldValue: Int
    let newValue: Int
    let delta: Int
}

// MARK: - Skill Update Helpers

extension SkillUpdateRow {
    /// Parse skill updates from the pipe-delimited or legacy summary string
    static func parseSkillUpdates(from summary: String) -> [SkillUpdateRow] {
        guard !summary.isEmpty else { return [] }
        return summary.components(separatedBy: "\n").compactMap { line in
            let pipeParts = line.components(separatedBy: "|")
            if pipeParts.count == 4 {
                let deltaVal = Int(pipeParts[3].replacingOccurrences(of: "+", with: "")) ?? 0
                return SkillUpdateRow(
                    skill: pipeParts[0],
                    oldValue: Int(pipeParts[1]) ?? 0,
                    newValue: Int(pipeParts[2]) ?? 0,
                    delta: deltaVal
                )
            }
            // Legacy format: "Dinking: 45% → 52% (+7)"
            let colonParts = line.components(separatedBy: ": ")
            guard colonParts.count == 2 else { return nil }
            let skill = colonParts[0]
            let rest = colonParts[1]
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let arrowParts = rest.components(separatedBy: " \u{2192} ")
            guard arrowParts.count == 2 else { return nil }
            let old = Int(arrowParts[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let newAndDelta = arrowParts[1].components(separatedBy: " ")
            let newVal = Int(newAndDelta[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let delta = newAndDelta.count >= 2 ? (Int(newAndDelta[1].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
            return SkillUpdateRow(skill: skill, oldValue: old, newValue: newVal, delta: delta)
        }
    }

    /// Returns the skill update with the largest absolute delta (the "hero" highlight)
    static func heroSkill(from updates: [SkillUpdateRow]) -> SkillUpdateRow? {
        updates.max(by: { abs($0.delta) < abs($1.delta) })
    }

    /// Returns the average delta across all skill updates (net change percentage)
    static func netChange(from updates: [SkillUpdateRow]) -> Int {
        guard !updates.isEmpty else { return 0 }
        let total = updates.reduce(0) { $0 + $1.delta }
        return total / updates.count
    }
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
