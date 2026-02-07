import Foundation

struct Session: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var duration: Int
    var notes: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: Int = 0,
        notes: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.notes = notes
        self.updatedAt = updatedAt
    }
}
