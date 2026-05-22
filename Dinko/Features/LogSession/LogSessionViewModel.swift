import Foundation

@Observable
final class LogSessionViewModel {
    var sessionType: SessionType = .game
    var selectedSkillIds: Set<UUID> = []
    var notes: String = ""
    var duration: Int = 60
    var skills: [Skill] = []
    var isSaving = false
    var errorMessage: String?
    var saveSucceeded = false

    private let skillRepository: SkillRepository
    private let sessionRepository: SessionRepository
    private let journalEntryRepository: JournalEntryRepository

    var canSave: Bool {
        !selectedSkillIds.isEmpty && !isSaving
    }

    var skillsByCategory: [(category: SkillCategory, skills: [Skill])] {
        let grouped = Dictionary(grouping: skills) { $0.category }
        return SkillCategory.allCases.compactMap { category in
            guard let categorySkills = grouped[category], !categorySkills.isEmpty else { return nil }
            return (category: category, skills: categorySkills.sorted { $0.displayOrder < $1.displayOrder })
        }
    }

    init(
        skillRepository: SkillRepository,
        sessionRepository: SessionRepository,
        journalEntryRepository: JournalEntryRepository
    ) {
        self.skillRepository = skillRepository
        self.sessionRepository = sessionRepository
        self.journalEntryRepository = journalEntryRepository
    }

    func loadSkills() async {
        do {
            let allSkills = try await skillRepository.fetchActive()
            skills = allSkills.filter { $0.hierarchyLevel == 0 }
        } catch {
            errorMessage = "Failed to load skills."
        }
    }

    func toggleSkill(_ id: UUID) {
        if selectedSkillIds.contains(id) {
            selectedSkillIds.remove(id)
        } else {
            selectedSkillIds.insert(id)
        }
    }

    func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil

        do {
            let skillIdsString = selectedSkillIds.map(\.uuidString).joined(separator: ",")
            let selectedSkillNames = skills
                .filter { selectedSkillIds.contains($0.id) }
                .map(\.name)
                .joined(separator: ", ")

            let session = Session(
                date: Date(),
                duration: duration,
                notes: notes.isEmpty ? nil : notes,
                sessionType: sessionType,
                skillIds: skillIdsString
            )

            try await sessionRepository.save(session)

            let journalEntry = JournalEntry(
                sessionId: session.id.uuidString,
                date: session.date,
                sessionType: sessionType.rawValue,
                durationMinutes: duration,
                userNote: notes,
                skillUpdatesSummary: selectedSkillNames,
                skillUpdatesCount: selectedSkillIds.count
            )

            try await journalEntryRepository.save(journalEntry)

            saveSucceeded = true
        } catch {
            errorMessage = "Failed to save session. Please try again."
        }

        isSaving = false
    }

    func reset() {
        selectedSkillIds = []
        notes = ""
        duration = 60
        isSaving = false
        errorMessage = nil
        saveSucceeded = false
    }
}
