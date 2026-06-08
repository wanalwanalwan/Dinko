import Foundation

@MainActor
@Observable
final class ProgramViewModel {
    private(set) var activeProgram: Program?
    private(set) var allSessions: [ProgramSession] = []
    private(set) var drillCounts: [UUID: Int] = [:]
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
        isGenerating = true
        errorMessage = nil

        do {
            let token = await getAuthToken()
            guard !token.isEmpty else {
                errorMessage = "Please sign in to generate a program."
                isGenerating = false
                return
            }

            // Gather skill data
            let allSkills = try await skillRepository.fetchActive()
            let topLevel = allSkills.filter { $0.parentSkillId == nil }

            var snapshots: [AgentService.SkillSnapshotPayload] = []
            for skill in topLevel {
                let children = allSkills.filter { $0.parentSkillId == skill.id }
                let latestRating = try await skillRatingRepository.fetchLatest(skill.id)
                let pendingDrills = try await drillRepository.fetchForSkill(skill.id)
                let pendingCount = pendingDrills.filter { $0.status == .pending }.count

                let subskills = await children.asyncMap { child -> AgentService.SubskillPayload in
                    let childRating = try? await self.skillRatingRepository.fetchLatest(child.id)
                    return AgentService.SubskillPayload(
                        id: child.id.uuidString,
                        name: child.name,
                        currentRating: childRating?.rating ?? 0
                    )
                }

                snapshots.append(AgentService.SkillSnapshotPayload(
                    id: skill.id.uuidString,
                    name: skill.name,
                    category: skill.category.rawValue,
                    currentRating: latestRating?.rating ?? 0,
                    parentSkillId: nil,
                    subskills: subskills,
                    pendingDrillCount: pendingCount
                ))
            }

            let profilePayload = PlayerProfile.current().toPayload()
            let weeklyGoal = UserDefaults.standard.integer(forKey: "pkkl_weekly_goal")

            let response = try await agentService.generateProgram(
                focusSkills: snapshots,
                playerProfile: profilePayload.isEmpty ? nil : profilePayload,
                weeklyGoal: max(weeklyGoal, 3),
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
