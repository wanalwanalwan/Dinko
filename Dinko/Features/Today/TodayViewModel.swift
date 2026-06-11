import SwiftUI

@Observable
final class TodayViewModel {

    // MARK: - Published State

    var todaysFocus: RecommendedFocus?
    var alternativeFocus: RecommendedFocus?
    var weekPlan: WeekPlan?
    var skillsAtTarget: Int = 0
    var totalTrackableSkills: Int = 0
    var staleCheckIns: [(skillName: String, skillId: UUID, confidence: Int)] = []
    var coachInsightText: String = ""
    var streakDays: Int = 0
    var goalDUPR: String = ""
    var milestoneSuggestion: ConfidenceSuggestion?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies (set from environment before calling loadToday)

    var skillRepository: SkillRepository?
    var confidenceEntryRepository: ConfidenceEntryRepository?
    var focusHistoryRepository: FocusHistoryRepository?
    var sessionRepository: SessionRepository?

    // MARK: - Load

    @MainActor
    func loadToday() async {
        guard let skillRepo = skillRepository,
              let confRepo = confidenceEntryRepository,
              let focusRepo = focusHistoryRepository,
              let sessionRepo = sessionRepository else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = PlayerProfile.current()
            goalDUPR = profile.goalDUPR ?? "4.0"

            guard let targetDUPR = ConfidenceBenchmark.targetDUPR(from: profile.goalDUPR) else {
                coachInsightText = "Set your goal DUPR to get personalized recommendations."
                return
            }

            // Fetch data in parallel
            let skills = try await skillRepo.fetchActive()
            let recentHistory = try await focusRepo.fetchRecent(limit: 50)

            // Build confidence map: skillId -> latest confidence
            var confidences: [UUID: Int] = [:]
            for skill in skills {
                if let latest = try await confRepo.fetchLatest(skill.id) {
                    confidences[skill.id] = latest.confidence
                }
            }

            // Run recommendation engine
            let input = RecommendationEngine.Input(
                skills: skills,
                confidences: confidences,
                goalDUPR: targetDUPR,
                recentHistory: recentHistory
            )
            let output = RecommendationEngine.recommend(input: input)
            todaysFocus = output.primary
            alternativeFocus = output.alternative

            // Compute skills at target
            var atTarget = 0
            var trackable = 0
            for skill in skills {
                guard let canonicalId = skill.canonicalId,
                      let target = ConfidenceBenchmark.target(canonicalId: canonicalId, targetDUPR: targetDUPR)
                else { continue }
                trackable += 1
                let current = confidences[skill.id] ?? 1
                if current >= target {
                    atTarget += 1
                }
            }
            skillsAtTarget = atTarget
            totalTrackableSkills = trackable

            // Weekly plan
            let weeklyGoal = profile.weeklyGoal ?? 3
            weekPlan = SchedulingEngine.generateWeekPlan(weeklyGoal: weeklyGoal)

            // Mark completed days from session history
            if var plan = weekPlan {
                let sessions = try await sessionRepo.fetchAll()
                let calendar = Calendar.current
                let today = Date()
                let weekStart = plan.weekStartDate

                for i in plan.days.indices {
                    let dayDate = calendar.date(byAdding: .day, value: plan.days[i].dayOfWeek - 1, to: weekStart) ?? today
                    let hasSession = sessions.contains { session in
                        calendar.isDate(session.date, inSameDayAs: dayDate)
                    }
                    plan.days[i].isCompleted = hasSession
                }
                weekPlan = plan
            }

            // Stale check-ins (skills not updated in 14+ days)
            let staleDate = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let staleEntries = try await confRepo.fetchStale(olderThan: staleDate)
            staleCheckIns = staleEntries.compactMap { entry in
                guard let skill = skills.first(where: { $0.id == entry.skillId }) else { return nil }
                return (skillName: skill.name, skillId: skill.id, confidence: entry.confidence)
            }

            // Streak (simple count of consecutive days with sessions)
            streakDays = await computeStreak(sessionRepo: sessionRepo)

            // Milestone suggestion (Phase 4)
            milestoneSuggestion = MilestoneSuggestionEngine.checkForSuggestion(
                skills: skills,
                confidences: confidences,
                history: recentHistory
            )

            // Coach insight (Phase 5)
            let pillarSummaries = SkillPillar.allCases.map { pillar -> SkillPillarSummary in
                let pillarGaps = RecommendationEngine.buildGapInfos(
                    skills: skills.filter { $0.pillar == pillar },
                    confidences: confidences,
                    targetDUPR: targetDUPR
                )
                let atTarget = pillarGaps.filter { $0.gap == 0 }.count
                let totalGap = pillarGaps.reduce(0) { $0 + $1.gap }
                return SkillPillarSummary(
                    pillar: pillar,
                    totalSkills: pillarGaps.count,
                    skillsAtTarget: atTarget,
                    totalGap: totalGap,
                    largestGapSkill: pillarGaps.max(by: { $0.gap < $1.gap })?.skill.name,
                    isCurrentFocus: pillar == output.bottleneckPillar
                )
            }

            let completedThisWeek = weekPlan?.completedDays ?? 0
            coachInsightText = CoachInsightGenerator.generate(context: .init(
                pillarSummaries: pillarSummaries,
                bottleneckPillar: output.bottleneckPillar,
                bottleneckSkillName: todaysFocus?.skill.name,
                skillsAtTarget: skillsAtTarget,
                totalSkills: totalTrackableSkills,
                streakDays: streakDays,
                completedThisWeek: completedThisWeek,
                weeklyGoal: weeklyGoal,
                recentHistory: recentHistory
            ))

        } catch {
            errorMessage = "Failed to load today's focus."
            #if DEBUG
            print("TodayViewModel.loadToday error: \(error)")
            #endif
        }
    }

    // MARK: - Actions

    @MainActor
    func swapFocus() {
        guard let alt = alternativeFocus else { return }
        let previous = todaysFocus
        todaysFocus = alt
        alternativeFocus = previous
    }

    @MainActor
    func handleStaleCheckIn(skillId: UUID, response: StaleCheckInCard.CheckInResponse) async {
        guard let confRepo = confidenceEntryRepository else { return }

        // Find current confidence
        let currentConf = staleCheckIns.first(where: { $0.skillId == skillId })?.confidence ?? 1
        let newConf = min(max(currentConf + response.confidenceAdjustment, 1), 10)

        let entry = ConfidenceEntry(
            skillId: skillId,
            confidence: newConf,
            source: .periodic
        )

        do {
            try await confRepo.save(entry)
            staleCheckIns.removeAll { $0.skillId == skillId }
        } catch {
            #if DEBUG
            print("TodayViewModel.handleStaleCheckIn error: \(error)")
            #endif
        }
    }

    @MainActor
    func acceptMilestoneSuggestion() async {
        guard let suggestion = milestoneSuggestion,
              let confRepo = confidenceEntryRepository else { return }

        let entry = ConfidenceEntry(
            skillId: suggestion.skillId,
            confidence: suggestion.suggestedConfidence,
            source: .checkIn
        )

        do {
            try await confRepo.save(entry)
            milestoneSuggestion = nil
        } catch {
            #if DEBUG
            print("TodayViewModel.acceptMilestoneSuggestion error: \(error)")
            #endif
        }
    }

    @MainActor
    func dismissMilestoneSuggestion() {
        milestoneSuggestion = nil
    }

    // MARK: - Helpers

    private func computeStreak(sessionRepo: SessionRepository) async -> Int {
        do {
            let sessions = try await sessionRepo.fetchAll()
            let calendar = Calendar.current
            var streak = 0
            var checkDate = Date()

            for _ in 0..<365 {
                let hasSession = sessions.contains { session in
                    calendar.isDate(session.date, inSameDayAs: checkDate)
                }
                if hasSession {
                    streak += 1
                } else if streak > 0 {
                    break
                }
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            }
            return streak
        } catch {
            return 0
        }
    }

}
