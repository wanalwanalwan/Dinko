import Foundation

struct Session: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var duration: Int
    var notes: String?
    var sessionType: SessionType
    var skillIds: String
    var updatedAt: Date

    var skillIdArray: [UUID] {
        get {
            guard !skillIds.isEmpty else { return [] }
            return skillIds.split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: Int = 0,
        notes: String? = nil,
        sessionType: SessionType = .game,
        skillIds: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.notes = notes
        self.sessionType = sessionType
        self.skillIds = skillIds
        self.updatedAt = updatedAt
    }
}
