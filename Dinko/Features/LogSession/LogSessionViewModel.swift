import Foundation

@Observable
final class LogSessionViewModel {
    var sessionType: SessionType = .game
    var sessionDate: Date = Date()
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
    var isQuickMode: Bool = false

    // Post-session check-in
    var focusSkillId: UUID?
    var focusSkillName: String?
    var showPostCheckIn: Bool = false

    private let skillRepository: SkillRepository
    private let sessionRepository: SessionRepository
    private let journalEntryRepository: JournalEntryRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository
    private let confidenceEntryRepository: ConfidenceEntryRepository

    var canSave: Bool {
        !isSaving
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
        drillRepository: DrillRepository,
        confidenceEntryRepository: ConfidenceEntryRepository
    ) {
        self.skillRepository = skillRepository
        self.sessionRepository = sessionRepository
        self.journalEntryRepository = journalEntryRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
        self.confidenceEntryRepository = confidenceEntryRepository
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

            if isQuickMode {
                await preselectRecentSkills()
            }
        } catch {
            errorMessage = "Failed to load skills."
        }
    }

    func preselectRecentSkills() async {
        do {
            let sessions = try await sessionRepository.fetchAll()
            let recentSessions = Array(sessions.prefix(3))

            var recentSkillIds: [UUID] = []
            for session in recentSessions {
                for id in session.skillIdArray where !recentSkillIds.contains(id) {
                    recentSkillIds.append(id)
                }
            }

            let idsToSelect: Set<UUID>
            if recentSkillIds.isEmpty {
                // No recent sessions — preselect all active skills
                idsToSelect = Set(skills.map(\.id))
            } else {
                // Only select skills that still exist in the active list
                let activeIds = Set(skills.map(\.id))
                idsToSelect = Set(recentSkillIds.filter { activeIds.contains($0) })
            }

            selectedSkillIds = idsToSelect
            for id in idsToSelect {
                skillRatings[id] = Double(currentRatings[id] ?? 50)
            }

            // Default duration to the last session's duration
            if let lastDuration = recentSessions.first?.duration, lastDuration > 0 {
                duration = lastDuration
            }
        } catch {
            // Non-critical — fall through with no preselection
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
                date: sessionDate,
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
                    let rating = SkillRating(skillId: skillId, rating: newRating, date: sessionDate)
                    try await skillRatingRepository.save(rating)
                }
            }

            for drillId in completedDrillIds {
                try await drillRepository.updateStatus(drillId, status: .completed)
            }

            // Award XP for session
            XPManager.awardForSession(type: sessionType)

            // Show post-session check-in if focus skill is set
            if focusSkillId != nil {
                showPostCheckIn = true
            } else {
                saveSucceeded = true
            }
        } catch {
            errorMessage = "Failed to save session. Please try again."
        }

        isSaving = false
    }

    /// Post-session check-in response.
    enum CheckInResponse: String {
        case struggling   // -1
        case improving    // 0 (no change, just log)
        case comfortable  // +1
        case confident    // +2
        case skip         // no entry

        var confidenceAdjustment: Int {
            switch self {
            case .struggling: return -1
            case .improving: return 0
            case .comfortable: return 1
            case .confident: return 2
            case .skip: return 0
            }
        }
    }

    func handleCheckIn(_ response: CheckInResponse) async {
        guard let skillId = focusSkillId, response != .skip else {
            saveSucceeded = true
            return
        }

        do {
            // Get current confidence
            let currentConf: Int
            if let latest = try await confidenceEntryRepository.fetchLatest(skillId) {
                currentConf = latest.confidence
            } else {
                currentConf = 1
            }

            let newConf = min(max(currentConf + response.confidenceAdjustment, 1), 10)

            let entry = ConfidenceEntry(
                skillId: skillId,
                confidence: newConf,
                source: .checkIn
            )
            try await confidenceEntryRepository.save(entry)
            XPManager.award(.checkIn)
        } catch {
            #if DEBUG
            print("LogSessionViewModel.handleCheckIn error: \(error)")
            #endif
        }

        saveSucceeded = true
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
        showPostCheckIn = false
    }
}
