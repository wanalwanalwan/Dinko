import Foundation

@MainActor
@Observable
final class SkillDetailViewModel {
    private(set) var skill: Skill
    private(set) var subskills: [Skill] = []
    private(set) var subskillRatings: [UUID: Int] = [:]
    private(set) var subskillDeltas: [UUID: Int] = [:]
    private(set) var ratings: [SkillRating] = []
    private(set) var latestRating: Int = 0
    private(set) var weeklyDelta: Int?
    private(set) var hasSubskills: Bool = false
    var errorMessage: String?

    var isParentSkill: Bool { skill.parentSkillId == nil }

    var lastUpdatedText: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: skill.updatedAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case 0: return "Last updated today"
        case 1: return "Last updated yesterday"
        default: return "Last updated \(days) days ago"
        }
    }

    private let skillRepository: SkillRepository
    private let skillRatingRepository: SkillRatingRepository

    init(
        skill: Skill,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository
    ) {
        self.skill = skill
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
    }

    func loadDetail() async {
        do {
            // Load subskills (use fetchAll so archived subskills are included)
            let allSkills = try await skillRepository.fetchAll()
            subskills = allSkills
                .filter { $0.parentSkillId == skill.id }
                .sorted { $0.displayOrder < $1.displayOrder }
            hasSubskills = !subskills.isEmpty

            // Load subskill ratings
            var subRatings: [UUID: Int] = [:]
            for sub in subskills {
                if let latest = try await skillRatingRepository.fetchLatest(sub.id) {
                    subRatings[sub.id] = latest.rating
                } else {
                    subRatings[sub.id] = 0
                }
            }
            subskillRatings = subRatings

            // Compute subskill deltas
            var deltas: [UUID: Int] = [:]
            for sub in subskills {
                let allRatings = try await skillRatingRepository.fetchForSkill(sub.id)
                    .sorted { $0.date > $1.date }
                if allRatings.count >= 2 {
                    deltas[sub.id] = allRatings[0].rating - allRatings[1].rating
                }
            }
            subskillDeltas = deltas

            if hasSubskills {
                // Parent rating = average of subskill ratings
                let rated = subRatings.values.filter { $0 > 0 }
                latestRating = rated.isEmpty ? 0 : rated.reduce(0, +) / rated.count
                ratings = []
            } else {
                // Direct ratings
                ratings = try await skillRatingRepository.fetchForSkill(skill.id)
                    .sorted { $0.date < $1.date }

                if let latest = try await skillRatingRepository.fetchLatest(skill.id) {
                    latestRating = latest.rating
                } else {
                    latestRating = 0
                }
            }

            // Compute weekly delta for this skill
            let calendar = Calendar.current
            let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
            let recentRatings = ratings.filter { $0.date >= oneWeekAgo }.sorted { $0.date < $1.date }
            if let oldest = recentRatings.first, let newest = recentRatings.last, oldest.id != newest.id {
                weeklyDelta = newest.rating - oldest.rating
            } else {
                weeklyDelta = nil
            }

            errorMessage = nil
        } catch {
            errorMessage = "Failed to load skill details."
        }
    }

    func saveRating(_ rating: Int, notes: String?) async -> Bool {
        let clampedRating = min(max(rating, 0), 100)
        do {
            let newRating = SkillRating(
                skillId: skill.id,
                rating: clampedRating,
                notes: notes
            )
            try await skillRatingRepository.save(newRating)
            await loadDetail()
            return true
        } catch {
            errorMessage = "Failed to save rating."
            return false
        }
    }

    func updateNotes(_ notes: String) async {
        var updated = skill
        updated.description = notes
        updated.updatedAt = Date()
        do {
            try await skillRepository.save(updated)
            skill = updated
        } catch {
            errorMessage = "Failed to save notes."
        }
    }

    func archiveSkill() async {
        do {
            // Archive the parent skill
            try await skillRepository.archive(skill.id)
            // Also archive all subskills
            for subskill in subskills {
                try await skillRepository.archive(subskill.id)
            }
            // Only update local state after repo confirms success
            skill.status = .archived
            skill.archivedDate = Date()
        } catch {
            // Reload to get the true state from the database
            await loadDetail()
            errorMessage = "Failed to archive skill."
        }
    }

    func deleteSkill() async -> Bool {
        do {
            // Delete all subskills first
            for subskill in subskills {
                try await skillRepository.delete(subskill.id)
            }
            // Delete the skill itself
            try await skillRepository.delete(skill.id)
            return true
        } catch {
            errorMessage = "Failed to delete skill."
            return false
        }
    }
}
