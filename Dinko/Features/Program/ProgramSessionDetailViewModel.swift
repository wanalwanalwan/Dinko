import Foundation

@MainActor
@Observable
final class ProgramSessionDetailViewModel {
    private(set) var session: ProgramSession
    private(set) var drills: [ProgramDrill] = []
    private(set) var isLoading = false
    private(set) var isGeneratingDrills = false
    private(set) var showCelebration = false
    var errorMessage: String?

    private let programRepository: ProgramRepository
    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository
    private let agentService = AgentService()

    init(
        session: ProgramSession,
        programRepository: ProgramRepository,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository
    ) {
        self.session = session
        self.programRepository = programRepository
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
    }

    // MARK: - Computed

    var allDrillsComplete: Bool {
        // No drills = nothing to block on (user can complete with just focus text)
        if drills.isEmpty { return true }
        return drills.allSatisfy { $0.status != .pending }
    }

    var completedDrillCount: Int {
        drills.filter { $0.status == .completed }.count
    }

    var totalMinutesRemaining: Int {
        drills.filter { $0.status == .pending }.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Actions

    func loadDrills() async {
        isLoading = true
        defer { isLoading = false }

        do {
            drills = try await programRepository.fetchDrills(for: session.id)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load drills."
        }
    }

    func generateDrills() async {
        isGeneratingDrills = true
        errorMessage = nil
        defer { isGeneratingDrills = false }

        do {
            let token = await AuthService.shared.validAccessToken() ?? ""
            guard !token.isEmpty else {
                errorMessage = "Please sign in to generate drills."
                return
            }

            let profile = PlayerProfile.current()
            let profilePayload = profile.toPayload()

            let skillName = session.title
                .replacingOccurrences(of: " Drill Day", with: "")
                .replacingOccurrences(of: " Day", with: "")

            // Look up the actual skill from CoreData to get real ratings & subskills
            let (matchedSkill, currentRating, subskillPayloads, trendPoints) = await lookupSkillData(skillName: skillName)

            let response = try await agentService.skillCoaching(
                skillName: matchedSkill?.name ?? skillName,
                category: matchedSkill?.category.rawValue ?? skillCategoryGuess(for: skillName),
                currentRating: currentRating,
                skillDescription: session.focus,
                subskills: subskillPayloads,
                pendingDrills: [],
                ratingTrend: trendPoints,
                playerProfile: profilePayload.isEmpty ? nil : profilePayload,
                authToken: token
            )

            // Convert DrillRecommendations to ProgramDrills
            let newDrills = response.drills.prefix(4).enumerated().map { order, drill in
                ProgramDrill(
                    programSessionId: session.id,
                    name: drill.name,
                    drillDescription: drill.description,
                    durationMinutes: drill.durationMinutes,
                    targetReps: 1,
                    equipment: drill.equipment ?? "Paddle, balls",
                    playerCount: drill.playerCount ?? 1,
                    displayOrder: order
                )
            }

            guard !newDrills.isEmpty else {
                errorMessage = "No drills were generated. Please try again."
                return
            }

            try await programRepository.saveDrillsForSession(session.id, drills: newDrills)
            self.drills = newDrills
        } catch {
            errorMessage = "Failed to generate drills. Please try again."
        }
    }

    func completeDrill(_ id: UUID) async {
        do {
            try await programRepository.completeDrill(id)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].status = .completed
                drills[index].completedReps = drills[index].targetReps
            }

            // Track total drills completed
            let total = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")
            UserDefaults.standard.set(total + 1, forKey: "pkkl_total_drills_completed")
        } catch {
            errorMessage = "Failed to complete drill."
        }
    }

    func incrementRep(_ id: UUID) async {
        do {
            try await programRepository.incrementDrillReps(id)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].completedReps += 1
                if drills[index].completedReps >= drills[index].targetReps {
                    drills[index].status = .completed

                    let total = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")
                    UserDefaults.standard.set(total + 1, forKey: "pkkl_total_drills_completed")
                }
            }
        } catch {
            errorMessage = "Failed to update reps."
        }
    }

    func skipDrill(_ id: UUID) async {
        do {
            try await programRepository.updateDrillStatus(id, status: .skipped)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].status = .skipped
            }
        } catch {
            errorMessage = "Failed to skip drill."
        }
    }

    func completeSession() async {
        do {
            try await programRepository.completeSession(session.id)
            session.status = .completed
            session.completedDate = Date()
            showCelebration = true
        } catch {
            errorMessage = "Failed to complete session."
        }
    }

    // MARK: - Private

    /// Look up the real skill from CoreData by matching the session's skill name,
    /// then fetch its current rating, subskills with ratings, and rating trend.
    private func lookupSkillData(
        skillName: String
    ) async -> (Skill?, Int, [AgentService.CoachingSubskillPayload], [AgentService.RatingTrendPoint]) {
        do {
            let allSkills = try await skillRepository.fetchActive()
            let lowerName = skillName.lowercased()

            // Match by name (case-insensitive, partial match)
            let matched = allSkills.first { skill in
                skill.name.lowercased() == lowerName
                || skill.name.lowercased().contains(lowerName)
                || lowerName.contains(skill.name.lowercased())
            }

            guard let skill = matched else {
                return (nil, 0, [], [])
            }

            // Get current rating
            let latestRating = try await skillRatingRepository.fetchLatest(skill.id)
            let currentRating = latestRating?.rating ?? 0

            // Get subskills and their ratings
            let subskills = allSkills.filter { $0.parentSkillId == skill.id }
            var subskillPayloads: [AgentService.CoachingSubskillPayload] = []
            for sub in subskills {
                let subRating = try await skillRatingRepository.fetchLatest(sub.id)
                subskillPayloads.append(AgentService.CoachingSubskillPayload(
                    name: sub.name,
                    currentRating: subRating?.rating ?? 0
                ))
            }

            // Get rating trend (last 10 ratings)
            let allRatings = try await skillRatingRepository.fetchForSkill(skill.id)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let trendPoints = allRatings
                .sorted { $0.date < $1.date }
                .suffix(10)
                .map { AgentService.RatingTrendPoint(date: formatter.string(from: $0.date), rating: $0.rating) }

            return (skill, currentRating, subskillPayloads, trendPoints)
        } catch {
            return (nil, 0, [], [])
        }
    }

    /// Best-effort category guess from the skill name for the coaching endpoint
    private func skillCategoryGuess(for skillName: String) -> String {
        let lower = skillName.lowercased()
        if lower.contains("dink") { return "dinking" }
        if lower.contains("drop") || lower.contains("3rd shot") { return "drops" }
        if lower.contains("drive") { return "drives" }
        if lower.contains("serve") || lower.contains("return") { return "serves" }
        if lower.contains("volley") || lower.contains("block") || lower.contains("reset") { return "defense" }
        if lower.contains("lob") || lower.contains("smash") || lower.contains("erne") || lower.contains("attack") { return "offense" }
        if lower.contains("stack") || lower.contains("position") || lower.contains("strateg") { return "strategy" }
        if lower.contains("footwork") || lower.contains("movement") || lower.contains("transition") { return "movement" }
        return "general"
    }
}
