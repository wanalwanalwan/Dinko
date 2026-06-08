import Foundation

struct Program: Identifiable, Hashable {
    let id: UUID
    var name: String
    var programDescription: String
    var totalWeeks: Int
    var sessionsPerWeek: Int
    var skillFocus: String
    var status: ProgramStatus
    var source: ProgramSource
    var isPremium: Bool
    var currentWeek: Int
    var currentSession: Int
    var createdDate: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        programDescription: String = "",
        totalWeeks: Int = 4,
        sessionsPerWeek: Int = 3,
        skillFocus: String = "",
        status: ProgramStatus = .active,
        source: ProgramSource = .ai,
        isPremium: Bool = false,
        currentWeek: Int = 1,
        currentSession: Int = 1,
        createdDate: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.programDescription = programDescription
        self.totalWeeks = totalWeeks
        self.sessionsPerWeek = sessionsPerWeek
        self.skillFocus = skillFocus
        self.status = status
        self.source = source
        self.isPremium = isPremium
        self.currentWeek = currentWeek
        self.currentSession = currentSession
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }

    var totalSessions: Int { totalWeeks * sessionsPerWeek }
}

enum ProgramStatus: String {
    case active
    case completed
    case paused
}

enum ProgramSource: String {
    case ai
    case curated
}
