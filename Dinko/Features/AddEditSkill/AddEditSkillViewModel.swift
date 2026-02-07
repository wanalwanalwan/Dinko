import Foundation

@Observable
final class AddEditSkillViewModel {
    var name: String = ""
    var category: SkillCategory = .dinking {
        didSet { iconName = category.iconName }
    }
    var iconName: String = SkillCategory.dinking.iconName
    var skillDescription: String = ""
    private(set) var subskills: [Skill] = []
    private(set) var errorMessage: String?
    private(set) var isSaving: Bool = false

    private let skillRepository: SkillRepository
    private let existingSkill: Skill?
    private let parentSkillId: UUID?

    var isEditing: Bool { existingSkill != nil }
    var isTopLevelSkill: Bool { existingSkill != nil && existingSkill?.parentSkillId == nil }
    var skillId: UUID? { existingSkill?.id }
    var navigationTitle: String {
        if isEditing { return "Edit Skill" }
        return parentSkillId != nil ? "New Subskill" : "New Skill"
    }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(
        skill: Skill? = nil,
        parentSkillId: UUID? = nil,
        skillRepository: SkillRepository
    ) {
        self.existingSkill = skill
        self.parentSkillId = parentSkillId
        self.skillRepository = skillRepository

        if let skill {
            name = skill.name
            category = skill.category
            iconName = skill.category.iconName
            skillDescription = skill.description
        }
    }

    func loadSubskills() async {
        guard let skillId = existingSkill?.id else { return }
        do {
            let allSkills = try await skillRepository.fetchActive()
            subskills = allSkills
                .filter { $0.parentSkillId == skillId }
                .sorted { $0.displayOrder < $1.displayOrder }
        } catch {
            // Silently fail — subskills are supplementary info
        }
    }

    func save() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            if let existing = existingSkill {
                var updated = existing
                updated.name = name.trimmingCharacters(in: .whitespaces)
                updated.category = category
                updated.iconName = category.iconName
                updated.description = skillDescription.trimmingCharacters(in: .whitespaces)
                updated.updatedAt = Date()
                try await skillRepository.save(updated)
            } else {
                let newSkill = Skill(
                    name: name.trimmingCharacters(in: .whitespaces),
                    parentSkillId: parentSkillId,
                    hierarchyLevel: parentSkillId != nil ? 1 : 0,
                    category: category,
                    description: skillDescription.trimmingCharacters(in: .whitespaces),
                    iconName: category.iconName
                )
                try await skillRepository.save(newSkill)
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = "Failed to save skill."
            return false
        }
    }
}
