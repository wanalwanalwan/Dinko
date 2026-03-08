import Foundation

struct JournalEntry: Identifiable, Hashable {
    let id: UUID
    var sessionId: String
    var date: Date
    var sessionType: String?
    var durationMinutes: Int
    var coachInsight: String
    var skillUpdatesSummary: String
    var skillUpdatesCount: Int
    var drillsCount: Int
    var drillNamesSummary: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        sessionId: String,
        date: Date = Date(),
        sessionType: String? = nil,
        durationMinutes: Int = 0,
        coachInsight: String = "",
        skillUpdatesSummary: String = "",
        skillUpdatesCount: Int = 0,
        drillsCount: Int = 0,
        drillNamesSummary: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.date = date
        self.sessionType = sessionType
        self.durationMinutes = durationMinutes
        self.coachInsight = coachInsight
        self.skillUpdatesSummary = skillUpdatesSummary
        self.skillUpdatesCount = skillUpdatesCount
        self.drillsCount = drillsCount
        self.drillNamesSummary = drillNamesSummary
        self.updatedAt = updatedAt
    }
}
