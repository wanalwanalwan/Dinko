import CoreData

extension JournalEntryEntity {
    func toDomain() -> JournalEntry {
        JournalEntry(
            id: id ?? UUID(),
            sessionId: sessionId ?? "",
            date: date ?? Date(),
            sessionType: sessionType,
            durationMinutes: Int(durationMinutes),
            userNote: userNote ?? "",
            coachInsight: coachInsight ?? "",
            skillUpdatesSummary: skillUpdatesSummary ?? "",
            skillUpdatesCount: Int(skillUpdatesCount),
            drillsCount: Int(drillsCount),
            drillNamesSummary: drillNamesSummary ?? "",
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from entry: JournalEntry) {
        id = entry.id
        sessionId = entry.sessionId
        date = entry.date
        sessionType = entry.sessionType
        durationMinutes = Int16(entry.durationMinutes)
        userNote = entry.userNote
        coachInsight = entry.coachInsight
        skillUpdatesSummary = entry.skillUpdatesSummary
        skillUpdatesCount = Int16(entry.skillUpdatesCount)
        drillsCount = Int16(entry.drillsCount)
        drillNamesSummary = entry.drillNamesSummary
        updatedAt = entry.updatedAt
    }
}
