import Foundation

struct ProgramFocusSkill: Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let category: String
    let currentRating: Int
    let priority: Int
}

@MainActor
@Observable
final class ProgramViewModel {
    private(set) var activeProgram: Program?
    private(set) var allSessions: [ProgramSession] = []
    private(set) var drillCounts: [UUID: Int] = [:]
    private(set) var templates: [ProgramTemplate] = []
    private(set) var isLoading = false
    private(set) var isGenerating = false
    var errorMessage: String?

    private let programRepository: ProgramRepository
    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let drillRepository: DrillRepository
    private let agentService = AgentService()
    private let authService = AuthService.shared

    init(
        programRepository: ProgramRepository,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        drillRepository: DrillRepository
    ) {
        self.programRepository = programRepository
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.drillRepository = drillRepository
    }

    // MARK: - Computed

    var currentWeekSessions: [ProgramSession] {
        guard let program = activeProgram else { return [] }
        return allSessions.filter { $0.weekNumber == program.currentWeek }
    }

    var otherWeekSessions: [[ProgramSession]] {
        guard let program = activeProgram else { return [] }
        var weeks: [[ProgramSession]] = []
        for week in 1...program.totalWeeks where week != program.currentWeek {
            let sessions = allSessions.filter { $0.weekNumber == week }
            if !sessions.isEmpty {
                weeks.append(sessions)
            }
        }
        return weeks
    }

    var completedSessionCount: Int {
        allSessions.filter { $0.status == .completed }.count
    }

    var overallProgress: Double {
        guard let program = activeProgram, program.totalSessions > 0 else { return 0 }
        return Double(completedSessionCount) / Double(program.totalSessions)
    }

    var currentSessionToStart: ProgramSession? {
        allSessions.first { $0.status == .available }
    }

    // MARK: - Actions

    func loadProgram() async {
        isLoading = true
        defer { isLoading = false }

        do {
            activeProgram = try await programRepository.fetchActive()
            if let program = activeProgram {
                allSessions = try await programRepository.fetchSessions(for: program.id)
                // Load drill counts per session
                var counts: [UUID: Int] = [:]
                for session in allSessions {
                    let drills = try await programRepository.fetchDrills(for: session.id)
                    counts[session.id] = drills.count
                }
                drillCounts = counts
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load program."
        }
    }

    func generateProgram() async {
        let profile = PlayerProfile.current()
        guard profile.isComplete else {
            errorMessage = "Complete your player profile in Settings before generating a program."
            return
        }

        isGenerating = true
        errorMessage = nil

        do {
            let token = await getAuthToken()
            guard !token.isEmpty else {
                errorMessage = "Please sign in to generate a program."
                isGenerating = false
                return
            }

            // Use in-memory focus skills instead of crawling CoreData
            let focusEntries = FocusSkillManager.shared.focusSkills
            let snapshots = focusEntries.map { entry -> AgentService.SkillSnapshotPayload in
                var snapshot = AgentService.SkillSnapshotPayload(
                    id: entry.id.uuidString,
                    name: entry.name,
                    category: entry.categoryRaw,
                    currentRating: entry.startingRating ?? 0,
                    parentSkillId: nil,
                    subskills: [],
                    pendingDrillCount: 0
                )
                snapshot.priority = entry.priorityIndex
                return snapshot
            }

            let profilePayload = profile.toPayload()
            let weeklyGoal = UserDefaults.standard.integer(forKey: "pkkl_weekly_goal")

            let response = try await agentService.generateProgram(
                focusSkills: snapshots,
                playerProfile: profilePayload.isEmpty ? nil : profilePayload,
                weeklyGoal: max(weeklyGoal, 3),
                generationMode: "general",
                authToken: token
            )

            // Map response to domain models
            let program = Program(
                name: response.name,
                programDescription: response.description,
                totalWeeks: response.totalWeeks,
                sessionsPerWeek: response.sessionsPerWeek,
                skillFocus: response.skillFocus
            )

            var sessions: [ProgramSession] = []
            var drillsMap: [UUID: [ProgramDrill]] = [:]

            for (index, sessionResp) in response.sessions.enumerated() {
                let isFirst = index == 0
                let session = ProgramSession(
                    programId: program.id,
                    weekNumber: sessionResp.weekNumber,
                    sessionNumber: sessionResp.sessionNumber,
                    title: sessionResp.title,
                    focus: sessionResp.focus,
                    estimatedMinutes: sessionResp.estimatedMinutes,
                    status: isFirst ? .available : .locked
                )
                sessions.append(session)

                let drills = sessionResp.drills.enumerated().map { (order, drillResp) in
                    ProgramDrill(
                        programSessionId: session.id,
                        name: drillResp.name,
                        drillDescription: drillResp.description,
                        durationMinutes: drillResp.durationMinutes,
                        targetReps: drillResp.targetReps,
                        equipment: drillResp.equipment,
                        playerCount: drillResp.playerCount,
                        displayOrder: order
                    )
                }
                drillsMap[session.id] = drills
            }

            try await programRepository.saveFullProgram(program, sessions: sessions, drills: drillsMap)
            await loadProgram()
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    func generateCustomProgram(focusSkills: [ProgramFocusSkill]) async {
        let profile = PlayerProfile.current()
        guard profile.isComplete else {
            errorMessage = "Complete your player profile in Settings before generating a program."
            return
        }

        isGenerating = true
        errorMessage = nil

        do {
            let token = await getAuthToken()
            guard !token.isEmpty else {
                errorMessage = "Please sign in to generate a program."
                isGenerating = false
                return
            }

            let snapshots = focusSkills.map { focus -> AgentService.SkillSnapshotPayload in
                var snapshot = AgentService.SkillSnapshotPayload(
                    id: focus.id.uuidString,
                    name: focus.name,
                    category: focus.category,
                    currentRating: focus.currentRating,
                    parentSkillId: nil,
                    subskills: [],
                    pendingDrillCount: 0
                )
                snapshot.priority = focus.priority
                return snapshot
            }

            let profilePayload = PlayerProfile.current().toPayload()
            let weeklyGoal = UserDefaults.standard.integer(forKey: "pkkl_weekly_goal")

            let response = try await agentService.generateProgram(
                focusSkills: snapshots,
                playerProfile: profilePayload.isEmpty ? nil : profilePayload,
                weeklyGoal: max(weeklyGoal, 3),
                generationMode: "custom_focus",
                authToken: token
            )

            let program = Program(
                name: response.name,
                programDescription: response.description,
                totalWeeks: response.totalWeeks,
                sessionsPerWeek: response.sessionsPerWeek,
                skillFocus: response.skillFocus
            )

            var sessions: [ProgramSession] = []
            var drillsMap: [UUID: [ProgramDrill]] = [:]

            for (index, sessionResp) in response.sessions.enumerated() {
                let isFirst = index == 0
                let session = ProgramSession(
                    programId: program.id,
                    weekNumber: sessionResp.weekNumber,
                    sessionNumber: sessionResp.sessionNumber,
                    title: sessionResp.title,
                    focus: sessionResp.focus,
                    estimatedMinutes: sessionResp.estimatedMinutes,
                    status: isFirst ? .available : .locked
                )
                sessions.append(session)

                let drills = sessionResp.drills.enumerated().map { (order, drillResp) in
                    ProgramDrill(
                        programSessionId: session.id,
                        name: drillResp.name,
                        drillDescription: drillResp.description,
                        durationMinutes: drillResp.durationMinutes,
                        targetReps: drillResp.targetReps,
                        equipment: drillResp.equipment,
                        playerCount: drillResp.playerCount,
                        displayOrder: order
                    )
                }
                drillsMap[session.id] = drills
            }

            try await programRepository.saveFullProgram(program, sessions: sessions, drills: drillsMap)
            await loadProgram()
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }

    func deleteProgram() async {
        guard let program = activeProgram else { return }
        do {
            try await programRepository.delete(program.id)
            activeProgram = nil
            allSessions = []
            drillCounts = [:]
        } catch {
            errorMessage = "Failed to delete program."
        }
    }

    func pauseProgram() async {
        guard let program = activeProgram else { return }
        do {
            try await programRepository.updateStatus(program.id, status: .paused)
            activeProgram?.status = .paused
        } catch {
            errorMessage = "Failed to pause program."
        }
    }

    func fetchSkillsWithRatings() async -> [(skill: Skill, rating: Int)] {
        do {
            let allSkills = try await skillRepository.fetchActive()
            let topLevel = allSkills.filter { $0.parentSkillId == nil }
            var results: [(skill: Skill, rating: Int)] = []
            for skill in topLevel {
                let latestRating = try await skillRatingRepository.fetchLatest(skill.id)
                results.append((skill: skill, rating: latestRating?.rating ?? 0))
            }
            return results
        } catch {
            return []
        }
    }

    func loadTemplates() {
        templates = ProgramTemplateLoader.loadAll()
    }

    func startCuratedProgram(_ template: ProgramTemplate) async {
        isGenerating = true
        errorMessage = nil

        do {
            // Delete current active program if exists
            if let existing = activeProgram {
                try await programRepository.delete(existing.id)
            }

            // Convert template to domain models
            let program = Program(
                name: template.name,
                programDescription: template.templateDescription,
                totalWeeks: template.totalWeeks,
                sessionsPerWeek: template.sessionsPerWeek,
                skillFocus: template.skillFocus,
                source: .curated,
                isPremium: template.isPremium
            )

            var sessions: [ProgramSession] = []
            var drillsMap: [UUID: [ProgramDrill]] = [:]

            for (index, templateSession) in template.sessions.enumerated() {
                let isFirst = index == 0
                let session = ProgramSession(
                    programId: program.id,
                    weekNumber: templateSession.weekNumber,
                    sessionNumber: templateSession.sessionNumber,
                    title: templateSession.title,
                    focus: templateSession.focus,
                    estimatedMinutes: templateSession.estimatedMinutes,
                    status: isFirst ? .available : .locked
                )
                sessions.append(session)

                let drills = templateSession.drills.enumerated().map { (order, templateDrill) in
                    ProgramDrill(
                        programSessionId: session.id,
                        name: templateDrill.name,
                        drillDescription: templateDrill.drillDescription,
                        durationMinutes: templateDrill.durationMinutes,
                        targetReps: templateDrill.targetReps,
                        equipment: templateDrill.equipment,
                        playerCount: templateDrill.playerCount,
                        displayOrder: order
                    )
                }
                drillsMap[session.id] = drills
            }

            try await programRepository.saveFullProgram(program, sessions: sessions, drills: drillsMap)
            await loadProgram()
        } catch {
            errorMessage = "Failed to start program."
        }

        isGenerating = false
    }

    // MARK: - Private

    private func getAuthToken() async -> String {
        if let token = await authService.validAccessToken() {
            return token
        }
        return ""
    }
}

// Async map helper
private extension Array {
    func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var results: [T] = []
        results.reserveCapacity(count)
        for element in self {
            results.append(await transform(element))
        }
        return results
    }
}
