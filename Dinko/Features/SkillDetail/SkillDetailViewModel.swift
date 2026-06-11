import Foundation

@MainActor
@Observable
final class SkillDetailViewModel {
    private(set) var skill: Skill
    private(set) var subskills: [Skill] = []
    private(set) var subskillRatings: [UUID: Int] = [:]
    private(set) var subskillDeltas: [UUID: Int] = [:]
    private(set) var ratings: [SkillRating] = []
    private(set) var drills: [Drill] = []
    private(set) var progressCheckers: [ProgressChecker] = []
    private(set) var latestRating: Int = 0
    private(set) var weeklyDelta: Int?
    private(set) var hasSubskills: Bool = false
    var showCompletionCelebration = false
    var errorMessage: String?

    // Confidence-based properties
    private(set) var currentConfidence: Int = 1
    private(set) var targetConfidence: Int?
    private(set) var confidenceGap: Int = 0
    private(set) var confidenceHistory: [ConfidenceEntry] = []
    private(set) var whyItMatters: String?
    private(set) var prerequisiteFor: [String] = []
    private(set) var isLocked: Bool = false
    private(set) var unmetPrereqs: [SkillPrerequisite] = []

    var isParentSkill: Bool { skill.parentSkillId == nil }

    var completedCheckersCount: Int {
        progressCheckers.filter(\.isCompleted).count
    }

    var checkerProgress: Double {
        guard !progressCheckers.isEmpty else { return 0 }
        return Double(completedCheckersCount) / Double(progressCheckers.count)
    }

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
    private let confidenceEntryRepository: ConfidenceEntryRepository
    private let drillRepository: DrillRepository
    private let progressCheckerRepository: ProgressCheckerRepository

    init(
        skill: Skill,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        confidenceEntryRepository: ConfidenceEntryRepository,
        drillRepository: DrillRepository,
        progressCheckerRepository: ProgressCheckerRepository
    ) {
        self.skill = skill
        self.skillRepository = skillRepository
        self.skillRatingRepository = skillRatingRepository
        self.confidenceEntryRepository = confidenceEntryRepository
        self.drillRepository = drillRepository
        self.progressCheckerRepository = progressCheckerRepository
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

            // Load confidence data
            if let latestEntry = try await confidenceEntryRepository.fetchLatest(skill.id) {
                currentConfidence = latestEntry.confidence
            } else {
                currentConfidence = 1
            }

            confidenceHistory = try await confidenceEntryRepository.fetchForSkill(skill.id)
                .sorted { $0.date < $1.date }

            // Compute target and gap from benchmarks
            let profile = PlayerProfile.current()
            if let canonicalId = skill.canonicalId,
               let targetDUPR = ConfidenceBenchmark.targetDUPR(from: profile.goalDUPR) {
                let target = ConfidenceBenchmark.target(canonicalId: canonicalId, targetDUPR: targetDUPR)
                targetConfidence = target
                confidenceGap = max(0, (target ?? 0) - currentConfidence)
            } else {
                targetConfidence = nil
                confidenceGap = 0
            }

            // Why it matters
            if let canonicalId = skill.canonicalId,
               let canonical = CanonicalSkill.find(canonicalId) {
                whyItMatters = canonical.whyItMatters
            } else {
                whyItMatters = nil
            }

            // Prerequisite for
            let allCanonicals = CanonicalSkill.all
            var prereqFor: [String] = []
            for canonical in allCanonicals {
                let prereqs = SkillPrerequisite.prerequisites(for: canonical.id)
                for prereq in prereqs {
                    if prereq.requiredCanonicalId == skill.canonicalId {
                        prereqFor.append(canonical.name)
                    }
                }
            }
            prerequisiteFor = prereqFor

            // Check if this skill is locked
            if let canonicalId = skill.canonicalId {
                // Build confidence map for prerequisite check
                var confidences: [String: Int] = [:]
                for s in allSkills {
                    if let cid = s.canonicalId {
                        if let entry = try await confidenceEntryRepository.fetchLatest(s.id) {
                            confidences[cid] = entry.confidence
                        }
                    }
                }
                isLocked = SkillPrerequisite.isLocked(canonicalId: canonicalId, confidences: confidences)
                unmetPrereqs = SkillPrerequisite.unmetPrerequisites(for: canonicalId, confidences: confidences)
            }

            // Load drills
            drills = try await drillRepository.fetchForSkill(skill.id)

            // Load progress checkers
            progressCheckers = try await progressCheckerRepository.fetchForSkill(skill.id)
                .sorted { $0.displayOrder < $1.displayOrder }

            errorMessage = nil
        } catch {
            errorMessage = "Failed to load skill details."
        }
    }

    func saveConfidence(_ confidence: Int) async {
        let clamped = max(1, min(10, confidence))
        let entry = ConfidenceEntry(
            skillId: skill.id,
            confidence: clamped,
            source: .manual
        )
        do {
            try await confidenceEntryRepository.save(entry)
            currentConfidence = clamped
            if let target = targetConfidence {
                confidenceGap = max(0, target - clamped)
            }
            // Reload confidence history
            confidenceHistory = try await confidenceEntryRepository.fetchForSkill(skill.id)
                .sorted { $0.date < $1.date }
        } catch {
            errorMessage = "Failed to save confidence."
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

            if clampedRating == 100 {
                try await skillRepository.archive(skill.id)
                skill.status = .completed
                skill.archivedDate = Date()
                showCompletionCelebration = true
            }

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

    func updateDrillStatus(_ drillId: UUID, status: DrillStatus) async {
        do {
            try await drillRepository.updateStatus(drillId, status: status)
            drills = try await drillRepository.fetchForSkill(skill.id)
        } catch {
            errorMessage = "Failed to update drill."
        }
    }

    func toggleChecker(_ id: UUID) async {
        do {
            try await progressCheckerRepository.toggleCompletion(id)
            progressCheckers = try await progressCheckerRepository.fetchForSkill(skill.id)
                .sorted { $0.displayOrder < $1.displayOrder }
        } catch {
            errorMessage = "Failed to update checker."
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
