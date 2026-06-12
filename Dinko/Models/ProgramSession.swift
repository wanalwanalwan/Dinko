import Foundation

struct ProgramSession: Identifiable, Hashable {
    let id: UUID
    var programId: UUID
    var weekNumber: Int
    var sessionNumber: Int
    var title: String
    var focus: String
    var estimatedMinutes: Int
    var scheduledDayOfWeek: Int?  // 0=Mon...6=Sun, nil for curated programs
    var status: ProgramSessionStatus
    var completedDate: Date?
    var createdDate: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        programId: UUID,
        weekNumber: Int,
        sessionNumber: Int,
        title: String,
        focus: String = "",
        estimatedMinutes: Int = 30,
        scheduledDayOfWeek: Int? = nil,
        status: ProgramSessionStatus = .locked,
        completedDate: Date? = nil,
        createdDate: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.programId = programId
        self.weekNumber = weekNumber
        self.sessionNumber = sessionNumber
        self.title = title
        self.focus = focus
        self.estimatedMinutes = estimatedMinutes
        self.scheduledDayOfWeek = scheduledDayOfWeek
        self.status = status
        self.completedDate = completedDate
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }
}

enum ProgramSessionStatus: String {
    case locked
    case available
    case completed
}
