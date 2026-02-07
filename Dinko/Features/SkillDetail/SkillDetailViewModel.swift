import Foundation

@Observable
final class SkillDetailViewModel {
    private(set) var skill: Skill
    private(set) var checkers: [ProgressChecker] = []
    private(set) var ratings: [SkillRating] = []
    private(set) var latestRating: Int = 0
    private(set) var errorMessage: String?

    private let skillRepository: SkillRepository
    private let progressCheckerRepository: ProgressCheckerRepository
    private let skillRatingRepository: SkillRatingRepository

    init(
        skill: Skill,
        skillRepository: SkillRepository,
        progressCheckerRepository: ProgressCheckerRepository,
        skillRatingRepository: SkillRatingRepository
    ) {
        self.skill = skill
        self.skillRepository = skillRepository
        self.progressCheckerRepository = progressCheckerRepository
        self.skillRatingRepository = skillRatingRepository
    }

    func loadDetail() async {
        do {
            checkers = try await progressCheckerRepository.fetchForSkill(skill.id)
                .sorted { $0.displayOrder < $1.displayOrder }

            ratings = try await skillRatingRepository.fetchForSkill(skill.id)
                .sorted { $0.date < $1.date }

            if let latest = try await skillRatingRepository.fetchLatest(skill.id) {
                latestRating = latest.rating
            }

            errorMessage = nil
        } catch {
            errorMessage = "Failed to load skill details."
        }
    }

    func toggleChecker(_ checker: ProgressChecker) async {
        do {
            try await progressCheckerRepository.toggleCompletion(checker.id)
            checkers = try await progressCheckerRepository.fetchForSkill(skill.id)
                .sorted { $0.displayOrder < $1.displayOrder }
        } catch {
            errorMessage = "Failed to update checker."
        }
    }

    func archiveSkill() async {
        do {
            try await skillRepository.archive(skill.id)
            skill.status = .archived
            skill.archivedDate = Date()
        } catch {
            errorMessage = "Failed to archive skill."
        }
    }
}
