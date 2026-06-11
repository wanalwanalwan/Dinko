import SwiftUI

/// Skill info for display in the Journey view.
struct JourneySkillInfo: Identifiable {
    let id: UUID
    let name: String
    let canonicalId: String?
    let pillar: SkillPillar
    let currentConfidence: Int
    let targetConfidence: Int
    let gap: Int
    let isCurrentFocus: Bool
    let isLocked: Bool
    let unmetPrerequisites: [String] // Display names of unmet prereqs
}

@Observable
final class JourneyViewModel {

    // MARK: - Published State

    var goalDUPR: String = ""
    var skillsAtTarget: Int = 0
    var totalTrackableSkills: Int = 0
    var pillarSummaries: [SkillPillarSummary] = []
    var bottleneckPillar: SkillPillar?
    var bottleneckSkillName: String?
    var bottleneckNarrative: String = ""
    var skillsByPillar: [SkillPillar: [JourneySkillInfo]] = [:]
    var expandedPillars: Set<SkillPillar> = []
    var currentFocusSkillId: UUID?
    var isLoading: Bool = false

    // MARK: - Dependencies

    var skillRepository: SkillRepository?
    var confidenceEntryRepository: ConfidenceEntryRepository?
    var focusHistoryRepository: FocusHistoryRepository?

    // MARK: - Load

    @MainActor
    func loadJourney() async {
        guard let skillRepo = skillRepository,
              let confRepo = confidenceEntryRepository,
              let focusRepo = focusHistoryRepository else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let profile = PlayerProfile.current()
            goalDUPR = profile.goalDUPR ?? "4.0"

            guard let targetDUPR = ConfidenceBenchmark.targetDUPR(from: profile.goalDUPR) else { return }

            let skills = try await skillRepo.fetchActive()
            let recentHistory = try await focusRepo.fetchRecent(limit: 50)

            // Build confidence map
            var confidences: [UUID: Int] = [:]
            for skill in skills {
                if let latest = try await confRepo.fetchLatest(skill.id) {
                    confidences[skill.id] = latest.confidence
                }
            }

            // Build gap infos
            let gapInfos = RecommendationEngine.buildGapInfos(
                skills: skills,
                confidences: confidences,
                targetDUPR: targetDUPR
            )

            // Bottleneck
            bottleneckPillar = RecommendationEngine.computeBottleneckPillar(
                gapInfos: gapInfos,
                targetDUPR: targetDUPR
            )

            // Recommendation for current focus
            let engineOutput = RecommendationEngine.recommend(input: .init(
                skills: skills,
                confidences: confidences,
                goalDUPR: targetDUPR,
                recentHistory: recentHistory
            ))
            currentFocusSkillId = engineOutput.primary?.skill.id

            // Build canonicalId -> confidence map for prereq checks
            var canonicalConfidences: [String: Int] = [:]
            for info in gapInfos {
                if let cid = info.skill.canonicalId {
                    canonicalConfidences[cid] = info.current
                }
            }

            // Build skill info per pillar
            var byPillar: [SkillPillar: [JourneySkillInfo]] = [:]
            var atTarget = 0
            var trackable = 0

            for pillar in SkillPillar.allCases {
                let pillarSkills = gapInfos
                    .filter { $0.skill.pillar == pillar }
                    .sorted { $0.skill.displayOrder < $1.skill.displayOrder }

                let infos = pillarSkills.map { info -> JourneySkillInfo in
                    let isLocked: Bool
                    let unmet: [String]
                    if let cid = info.skill.canonicalId {
                        isLocked = SkillPrerequisite.isLocked(canonicalId: cid, confidences: canonicalConfidences)
                        unmet = SkillPrerequisite.unmetPrerequisites(for: cid, confidences: canonicalConfidences)
                            .compactMap { prereq in
                                CanonicalSkill.find(prereq.requiredSkillCanonicalId)?.name
                            }
                    } else {
                        isLocked = false
                        unmet = []
                    }

                    if info.current >= info.target { atTarget += 1 }
                    trackable += 1

                    return JourneySkillInfo(
                        id: info.skill.id,
                        name: info.skill.name,
                        canonicalId: info.skill.canonicalId,
                        pillar: pillar,
                        currentConfidence: info.current,
                        targetConfidence: info.target,
                        gap: info.gap,
                        isCurrentFocus: info.skill.id == currentFocusSkillId,
                        isLocked: isLocked,
                        unmetPrerequisites: unmet
                    )
                }
                byPillar[pillar] = infos
            }

            skillsByPillar = byPillar
            skillsAtTarget = atTarget
            totalTrackableSkills = trackable

            // Pillar summaries
            pillarSummaries = SkillPillar.allCases.map { pillar in
                let skills = byPillar[pillar] ?? []
                let atTarget = skills.filter { $0.gap == 0 }.count
                let totalGap = skills.reduce(0) { $0 + $1.gap }
                let largestGap = skills.max(by: { $0.gap < $1.gap })
                return SkillPillarSummary(
                    pillar: pillar,
                    totalSkills: skills.count,
                    skillsAtTarget: atTarget,
                    totalGap: totalGap,
                    largestGapSkill: largestGap?.name,
                    isCurrentFocus: pillar == bottleneckPillar
                )
            }

            // Bottleneck narrative
            if let bp = bottleneckPillar {
                let bpSkill = engineOutput.primary?.skill.name ?? "your skills"
                bottleneckSkillName = engineOutput.primary?.skill.name
                bottleneckNarrative = "Your \(bp.displayName) game has the largest gap. Focus on \(bpSkill) to make the biggest impact."
            }

            // Auto-expand bottleneck pillar
            if let bp = bottleneckPillar {
                expandedPillars.insert(bp)
            }

        } catch {
            #if DEBUG
            print("JourneyViewModel.loadJourney error: \(error)")
            #endif
        }
    }

    func togglePillar(_ pillar: SkillPillar) {
        if expandedPillars.contains(pillar) {
            expandedPillars.remove(pillar)
        } else {
            expandedPillars.insert(pillar)
        }
    }
}
