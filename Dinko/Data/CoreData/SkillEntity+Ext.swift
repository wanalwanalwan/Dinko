import CoreData

extension SkillEntity {
    func toDomain() -> Skill {
        // Backward compat: treat legacy "archived" values as .completed
        let resolvedStatus: SkillStatus
        if let raw = status, raw == "archived" {
            resolvedStatus = .completed
        } else {
            resolvedStatus = SkillStatus(rawValue: status ?? "active") ?? .active
        }

        return Skill(
            id: id ?? UUID(),
            name: name ?? "",
            parentSkillId: parentSkillId,
            hierarchyLevel: Int(hierarchyLevel),
            category: SkillCategory(rawValue: category ?? "dinking") ?? .dinking,
            description: descriptionText ?? "",
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date(),
            status: resolvedStatus,
            archivedDate: archivedDate,
            displayOrder: Int(displayOrder),
            autoCalculateRating: autoCalculateRating,
            iconName: (SkillCategory(rawValue: category ?? "dinking") ?? .dinking).iconName
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
