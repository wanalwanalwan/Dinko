import Foundation

struct ProgressChecker: Identifiable, Hashable {
    let id: UUID
    var skillId: UUID
    var name: String
    var isCompleted: Bool
    var completedDate: Date?
    var displayOrder: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        skillId: UUID,
        name: String,
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        displayOrder: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.name = name
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.displayOrder = displayOrder
        self.updatedAt = updatedAt
    }
}
