import Foundation

@MainActor
@Observable
final class ArchivedSkillsViewModel {
    private(set) var skills: [Skill] = []
    private(set) var latestRatings: [UUID: Int] = [:]
    var errorMessage: String?

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository

    init(skillRepository: SkillRepository, skillRatingRepository: SkillRatingRepository) {
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
    }

    func loadSkills() async {
        do {
            let allArchived = try await skillRepository.fetchArchived()

            // Only show top-level skills
            skills = allArchived.filter { $0.parentSkillId == nil }

            var ratings: [UUID: Int] = [:]
            for skill in skills {
                let childSkills = allArchived.filter { $0.parentSkillId == skill.id }
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
            errorMessage = "Failed to load archived skills."
        }
    }
}
