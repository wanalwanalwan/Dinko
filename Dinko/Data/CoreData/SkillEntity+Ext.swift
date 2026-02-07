import CoreData

extension SkillEntity {
    func toDomain() -> Skill {
        Skill(
            id: id ?? UUID(),
            name: name ?? "",
            parentSkillId: parentSkillId,
            hierarchyLevel: Int(hierarchyLevel),
            category: SkillCategory(rawValue: category ?? "general") ?? .general,
            description: descriptionText ?? "",
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date(),
            status: SkillStatus(rawValue: status ?? "active") ?? .active,
            archivedDate: archivedDate,
            displayOrder: Int(displayOrder),
            autoCalculateRating: autoCalculateRating,
            iconName: iconName ?? "figure.pickleball"
        )
    }

    func update(from skill: Skill) {
        id = skill.id
        name = skill.name
        parentSkillId = skill.parentSkillId
        hierarchyLevel = Int16(skill.hierarchyLevel)
        category = skill.category.rawValue
        descriptionText = skill.description
        createdDate = skill.createdDate
        updatedAt = skill.updatedAt
        status = skill.status.rawValue
        archivedDate = skill.archivedDate
        displayOrder = Int16(skill.displayOrder)
        autoCalculateRating = skill.autoCalculateRating
        iconName = skill.iconName
    }
}
