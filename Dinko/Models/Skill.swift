import Foundation

struct Skill: Identifiable, Hashable {
    let id: UUID
    var name: String
    var parentSkillId: UUID?
    var hierarchyLevel: Int
    var category: SkillCategory
    var description: String
    var createdDate: Date
    var updatedAt: Date
    var status: SkillStatus
    var archivedDate: Date?
    var displayOrder: Int
    var autoCalculateRating: Bool
    var iconName: String

    init(
        id: UUID = UUID(),
        name: String,
        parentSkillId: UUID? = nil,
        hierarchyLevel: Int = 0,
        category: SkillCategory = .dinking,
        description: String = "",
        createdDate: Date = Date(),
        updatedAt: Date = Date(),
        status: SkillStatus = .active,
        archivedDate: Date? = nil,
        displayOrder: Int = 0,
        autoCalculateRating: Bool = false,
        iconName: String = "🥒"
    ) {
        self.id = id
        self.name = name
        self.parentSkillId = parentSkillId
        self.hierarchyLevel = hierarchyLevel
        self.category = category
        self.description = description
        self.createdDate = createdDate
        self.updatedAt = updatedAt
        self.status = status
        self.archivedDate = archivedDate
        self.displayOrder = displayOrder
        self.autoCalculateRating = autoCalculateRating
        self.iconName = iconName
    }
}
