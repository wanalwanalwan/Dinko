import Foundation

struct SkillRating: Identifiable, Hashable {
    let id: UUID
    var skillId: UUID
    var rating: Int
    var date: Date
    var notes: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        skillId: UUID,
        rating: Int,
        date: Date = Date(),
        notes: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.rating = min(max(rating, 0), 100)
        self.date = date
        self.notes = notes
        self.updatedAt = updatedAt
    }
}
