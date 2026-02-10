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
    private(set) var hasSubskills: Bool = false
    var errorMessage: String?

    var isParentSkill: Bool { skill.parentSkillId == nil }

    /// Ratings deduplicated to the last entry per calendar day, for chart display
    var chartRatings: [SkillRating] {
        let calendar = Calendar.current
        var lastPerDay: [DateComponents: SkillRating] = [:]
        for rating in ratings {
            let day = calendar.dateComponents([.year, .month, .day], from: rating.date)
            if let existing = lastPerDay[day] {
                if rating.date >= existing.date {
                    lastPerDay[day] = rating
                }
            } else {
                lastPerDay[day] = rating
            }
        }
        return lastPerDay.values.sorted { $0.date < $1.date }
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

                // Build synthetic rating history from subskill averages per date
                var allSubRatings: [SkillRating] = []
                for sub in subskills {
                    let subHistory = try await skillRatingRepository.fetchForSkill(sub.id)
                    allSubRatings.append(contentsOf: subHistory)
                }

                let calendar = Calendar.current
                // Get all unique dates across subskills
                let uniqueDays = Set(allSubRatings.map { calendar.startOfDay(for: $0.date) })
                    .sorted()

                var syntheticRatings: [SkillRating] = []
                for day in uniqueDays {
                    // For each day, compute the average using the latest known rating for each subskill up to that day
                    var dayAverages: [Int] = []
                    for sub in subskills {
                        let subHistory = allSubRatings
                            .filter { $0.skillId == sub.id && $0.date <= calendar.date(byAdding: .day, value: 1, to: day)! }
                            .sorted { $0.date < $1.date }
                        if let latest = subHistory.last {
                            dayAverages.append(latest.rating)
                        }
                    }
                    if !dayAverages.isEmpty {
                        let avg = dayAverages.reduce(0, +) / dayAverages.count
                        syntheticRatings.append(SkillRating(
                            skillId: skill.id,
                            rating: avg,
                            date: day
                        ))
                    }
                }
                ratings = syntheticRatings
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
