import Foundation

@Observable
final class AddEditSkillViewModel {
    var name: String = ""
    var category: SkillCategory = .general
    var iconName: String = "figure.pickleball"
    var skillDescription: String = ""
    var checkerNames: [String] = [""]
    private(set) var errorMessage: String?
    private(set) var isSaving: Bool = false

    private let skillRepository: SkillRepository
    private let progressCheckerRepository: ProgressCheckerRepository
    private let existingSkill: Skill?

    var isEditing: Bool { existingSkill != nil }
    var navigationTitle: String { isEditing ? "Edit Skill" : "New Skill" }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    init(
        skill: Skill? = nil,
        skillRepository: SkillRepository,
        progressCheckerRepository: ProgressCheckerRepository
    ) {
        self.existingSkill = skill
        self.skillRepository = skillRepository
        self.progressCheckerRepository = progressCheckerRepository

        if let skill {
            name = skill.name
            category = skill.category
            iconName = skill.iconName
            skillDescription = skill.description
        }
    }

    func loadExistingCheckers() async {
        guard let skill = existingSkill else { return }
        do {
            let checkers = try await progressCheckerRepository.fetchForSkill(skill.id)
                .sorted { $0.displayOrder < $1.displayOrder }
            if !checkers.isEmpty {
                checkerNames = checkers.map(\.name)
            }
        } catch {
            errorMessage = "Failed to load checkers."
        }
    }

    func addChecker() {
        checkerNames.append("")
    }

    func removeChecker(at index: Int) {
        guard checkerNames.count > 1 else { return }
        checkerNames.remove(at: index)
    }

    func save() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            let skillId: UUID
            if let existing = existingSkill {
                skillId = existing.id
                var updated = existing
                updated.name = name.trimmingCharacters(in: .whitespaces)
                updated.category = category
                updated.iconName = iconName
                updated.description = skillDescription.trimmingCharacters(in: .whitespaces)
                updated.updatedAt = Date()
                try await skillRepository.save(updated)
            } else {
                let newSkill = Skill(
                    name: name.trimmingCharacters(in: .whitespaces),
                    category: category,
                    description: skillDescription.trimmingCharacters(in: .whitespaces),
                    iconName: iconName
                )
                skillId = newSkill.id
                try await skillRepository.save(newSkill)
            }

            // Save checkers: delete existing, re-create from current list
            if existingSkill != nil {
                let oldCheckers = try await progressCheckerRepository.fetchForSkill(skillId)
                for checker in oldCheckers {
                    try await progressCheckerRepository.delete(checker.id)
                }
            }

            let validCheckers = checkerNames
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            for (index, checkerName) in validCheckers.enumerated() {
                let checker = ProgressChecker(
                    skillId: skillId,
                    name: checkerName,
                    displayOrder: index
                )
                try await progressCheckerRepository.save(checker)
            }

            errorMessage = nil
            return true
        } catch {
            errorMessage = "Failed to save skill."
            return false
        }
    }
}
