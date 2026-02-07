import Foundation

struct PendingSubskill: Identifiable {
    let id = UUID()
    var name: String
    var rating: Double = 0
}

@Observable
final class AddEditSkillViewModel {
    var name: String = ""
    var category: SkillCategory = .dinking {
        didSet { iconName = category.iconName }
    }
    var iconName: String = SkillCategory.dinking.iconName
    var skillDescription: String = ""
    var initialRating: Double = 0
    var pendingSubskills: [PendingSubskill] = []
    var newSubskillName: String = ""
    private(set) var subskills: [Skill] = []
    private(set) var errorMessage: String?
    private(set) var isSaving: Bool = false

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
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

    /// Show inline subskill creation when creating a new top-level skill
    var showInlineSubskills: Bool { !isEditing && parentSkillId == nil }

    /// Show existing subskills list when editing a top-level skill
    var showExistingSubskills: Bool { isTopLevelSkill }

    /// Show initial rating slider when creating any new skill (not editing)
    var showInitialRating: Bool { !isEditing }

    init(
        skill: Skill? = nil,
        parentSkillId: UUID? = nil,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository
    ) {
        self.existingSkill = skill
        self.parentSkillId = parentSkillId
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository

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

    func addPendingSubskill() {
        let trimmed = newSubskillName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        pendingSubskills.append(PendingSubskill(name: trimmed))
        newSubskillName = ""
    }

    func removePendingSubskill(_ subskill: PendingSubskill) {
        pendingSubskills.removeAll { $0.id == subskill.id }
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
                // Phase 1: Save parent skill
                let newSkill = Skill(
                    name: name.trimmingCharacters(in: .whitespaces),
                    parentSkillId: parentSkillId,
                    hierarchyLevel: parentSkillId != nil ? 1 : 0,
                    category: category,
                    description: skillDescription.trimmingCharacters(in: .whitespaces),
                    autoCalculateRating: !pendingSubskills.isEmpty,
                    iconName: category.iconName
                )
                try await skillRepository.save(newSkill)

                // Phase 2: Save pending subskills
                for (index, pending) in pendingSubskills.enumerated() {
                    let subskill = Skill(
                        name: pending.name,
                        parentSkillId: newSkill.id,
                        hierarchyLevel: 1,
                        category: category,
                        description: "",
                        displayOrder: index,
                        iconName: category.iconName
                    )
                    try await skillRepository.save(subskill)

                    // Save subskill rating if > 0
                    let subRating = Int(pending.rating)
                    if subRating > 0 {
                        let rating = SkillRating(skillId: subskill.id, rating: subRating)
                        try await skillRatingRepository.save(rating)
                    }
                }

                // Phase 3: Save parent rating if > 0
                let parentRating = Int(initialRating)
                if parentRating > 0 {
                    let rating = SkillRating(skillId: newSkill.id, rating: parentRating)
                    try await skillRatingRepository.save(rating)
                }
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = "Failed to save skill."
            return false
        }
    }
}
