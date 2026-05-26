import Foundation

@MainActor
@Observable
final class SkillCoachingViewModel {
    private(set) var gameTips: [GameTip] = []
    private(set) var drills: [DrillRecommendation] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var addedDrillIndices: Set<Int> = []

    private let skill: Skill
    private let subskills: [Skill]
    private let subskillRatings: [UUID: Int]
    private let currentRating: Int
    private let existingDrills: [Drill]
    private let ratings: [SkillRating]
    private let drillRepository: DrillRepository
    private let agentService = AgentService()
    private let authService = AuthService.shared

    init(
        skill: Skill,
        subskills: [Skill],
        subskillRatings: [UUID: Int],
        currentRating: Int,
        existingDrills: [Drill],
        ratings: [SkillRating],
        drillRepository: DrillRepository
    ) {
        self.skill = skill
        self.subskills = subskills
        self.subskillRatings = subskillRatings
        self.currentRating = currentRating
        self.existingDrills = existingDrills
        self.ratings = ratings
        self.drillRepository = drillRepository
    }

    func generateCoaching() async {
        isLoading = true
        errorMessage = nil
        gameTips = []
        drills = []
        addedDrillIndices = []

        do {
            let token = await getAuthToken()
            let profilePayload = PlayerProfile.current().toPayload()
            let response: SkillCoachingResponse = try await agentService.skillCoaching(
                skillName: skill.name,
                category: skill.category.rawValue,
                currentRating: currentRating,
                skillDescription: skill.description,
                subskills: subskills.map { sub in
                    AgentService.CoachingSubskillPayload(
                        name: sub.name,
                        currentRating: subskillRatings[sub.id] ?? 0
                    )
                },
                pendingDrills: existingDrills
                    .filter { $0.status == .pending }
                    .map { AgentService.PendingDrillPayload(name: $0.name, targetSubskill: $0.targetSubskill) },
                ratingTrend: buildRatingTrend(),
                playerProfile: profilePayload.isEmpty ? nil : profilePayload,
                authToken: token
            )
            gameTips = response.gameTips
            drills = response.drills
        } catch is CancellationError {
            // Task was cancelled, no error to show
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func addDrill(at index: Int) async {
        guard index < drills.count, !addedDrillIndices.contains(index) else { return }

        let rec = drills[index]
        let drill = Drill(
            skillId: skill.id,
            name: rec.name,
            drillDescription: rec.description,
            targetSubskill: rec.targetSubskill,
            durationMinutes: rec.durationMinutes,
            playerCount: rec.playerCount ?? 1,
            equipment: rec.equipment ?? "",
            reason: rec.reason,
            priority: rec.priority
        )

        do {
            try await drillRepository.save(drill)
            addedDrillIndices.insert(index)
        } catch {
            errorMessage = "Failed to save drill."
        }
    }

    // MARK: - Private

    private func getAuthToken() async -> String {
        if let token = await authService.validAccessToken() {
            return token
        }
        return ""
    }

    private func buildRatingTrend() -> [AgentService.RatingTrendPoint] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sorted = ratings.sorted { $0.date < $1.date }
        let recent = sorted.suffix(10)

        return recent.map { rating in
            AgentService.RatingTrendPoint(
                date: formatter.string(from: rating.date),
                rating: rating.rating
            )
        }
    }
}
