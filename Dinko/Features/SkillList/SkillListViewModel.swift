import Foundation

@Observable
final class SkillListViewModel {
    private(set) var skills: [Skill] = []
    private(set) var subskillCounts: [UUID: Int] = [:]
    private(set) var latestRatings: [UUID: Int] = [:]
    private(set) var errorMessage: String?

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository

    init(skillRepository: SkillRepository, skillRatingRepository: SkillRatingRepository) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
    }

    func loadSkills() async {
        do {
            let allSkills = try await skillRepository.fetchActive()

            // Only show top-level skills (no parent)
            skills = allSkills
                .filter { $0.parentSkillId == nil }
                .sorted { $0.displayOrder < $1.displayOrder }

            // Compute subskill counts
            var counts: [UUID: Int] = [:]
            for skill in skills {
                counts[skill.id] = allSkills.filter { $0.parentSkillId == skill.id }.count
            }
            subskillCounts = counts

            // Compute ratings: if has subskills, average of subskill ratings; otherwise latest direct rating
            var ratings: [UUID: Int] = [:]
            for skill in skills {
                let childSkills = allSkills.filter { $0.parentSkillId == skill.id }
                if childSkills.isEmpty {
                    if let latest = try await skillRatingRepository.fetchLatest(skill.id) {
                        ratings[skill.id] = latest.rating
                    } else {
                        ratings[skill.id] = 0
                    }
                } else {
                    var total = 0
                    var count = 0
                    for child in childSkills {
                        if let latest = try await skillRatingRepository.fetchLatest(child.id) {
                            total += latest.rating
                            count += 1
                        }
                    }
                    ratings[skill.id] = count > 0 ? total / count : 0
                }
            }
            latestRatings = ratings
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load skills. Please try again."
        }
    }
}
