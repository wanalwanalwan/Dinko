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
    var skillRatings: [UUID: Double] = [:]
    var currentRatings: [UUID: Int] = [:]
    var skillDrills: [UUID: [Drill]] = [:]
    var completedDrillIds: Set<UUID> = []

    private let skillRepository: SkillRepository
    private let sessionRepository: SessionRepository
    private let journalEntryRepository: JournalEntryRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository

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
        journalEntryRepository: JournalEntryRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository
    ) {
        self.skillRepository = skillRepository
        self.sessionRepository = sessionRepository
        self.journalEntryRepository = journalEntryRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
    }

    func loadSkills() async {
        do {
            let allSkills = try await skillRepository.fetchActive()
            skills = allSkills.filter { $0.hierarchyLevel == 0 }

            for skill in skills {
                if let latest = try await skillRatingRepository.fetchLatest(skill.id) {
                    currentRatings[skill.id] = latest.rating
                }
            }
        } catch {
            errorMessage = "Failed to load skills."
        }
    }

    func toggleSkill(_ id: UUID) {
        if selectedSkillIds.contains(id) {
            selectedSkillIds.remove(id)
            skillRatings.removeValue(forKey: id)
            if let drills = skillDrills.removeValue(forKey: id) {
                for drill in drills {
                    completedDrillIds.remove(drill.id)
                }
            }
        } else {
            selectedSkillIds.insert(id)
            skillRatings[id] = Double(currentRatings[id] ?? 50)
            if sessionType == .drill {
                Task { await loadDrills(for: id) }
            }
        }
    }

    func loadDrills(for skillId: UUID) async {
        do {
            let drills = try await drillRepository.fetchForSkill(skillId)
            skillDrills[skillId] = drills.filter { $0.status == .pending }
        } catch {
            // Drills are non-critical — don't block the session
        }
    }

    func toggleDrill(_ drillId: UUID) {
        if completedDrillIds.contains(drillId) {
            completedDrillIds.remove(drillId)
        } else {
            completedDrillIds.insert(drillId)
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

            for (skillId, value) in skillRatings {
                let newRating = Int(value)
                if newRating != currentRatings[skillId] {
                    let rating = SkillRating(skillId: skillId, rating: newRating)
                    try await skillRatingRepository.save(rating)
                }
            }

            for drillId in completedDrillIds {
                try await drillRepository.updateStatus(drillId, status: .completed)
            }

            saveSucceeded = true
        } catch {
            errorMessage = "Failed to save session. Please try again."
        }

        isSaving = false
    }

    func reset() {
        selectedSkillIds = []
        skillRatings = [:]
        currentRatings = [:]
        skillDrills = [:]
        completedDrillIds = []
        notes = ""
        duration = 60
        isSaving = false
        errorMessage = nil
        saveSucceeded = false
    }
}
