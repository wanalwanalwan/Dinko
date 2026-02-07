import Foundation

@Observable
final class SkillListViewModel {
    private(set) var skills: [Skill] = []
    private(set) var subskillCounts: [UUID: Int] = [:]
    private(set) var completionPercentages: [UUID: Int] = [:]
    private(set) var errorMessage: String?

    private let skillRepository: SkillRepository
    private let progressCheckerRepository: ProgressCheckerRepository

    init(skillRepository: SkillRepository, progressCheckerRepository: ProgressCheckerRepository) {
        self.skillRepository = skillRepository
        self.progressCheckerRepository = progressCheckerRepository
    }

    func loadSkills() async {
        do {
            let allSkills = try await skillRepository.fetchActive()
            skills = allSkills.sorted { $0.displayOrder < $1.displayOrder }

            // Compute subskill counts: count children where parentSkillId matches
            var counts: [UUID: Int] = [:]
            for skill in allSkills {
                counts[skill.id] = allSkills.filter { $0.parentSkillId == skill.id }.count
            }
            subskillCounts = counts

            // Compute completion percentages from checkers
            var percentages: [UUID: Int] = [:]
            for skill in skills {
                let checkers = try await progressCheckerRepository.fetchForSkill(skill.id)
                if checkers.isEmpty {
                    percentages[skill.id] = 0
                } else {
                    let completed = checkers.filter(\.isCompleted).count
                    percentages[skill.id] = (completed * 100) / checkers.count
                }
            }
            completionPercentages = percentages
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load skills. Please try again."
        }
    }
}
