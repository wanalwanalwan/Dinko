import Foundation

/// Bottleneck-first recommendation engine.
/// Stage 1: Identify bottleneck pillar (highest weighted gap).
/// Stage 2: Identify bottleneck skill within pillar (highest priority via dependency, recency, variety).
final class RecommendationEngine {

    struct Input {
        let skills: [Skill]
        let confidences: [UUID: Int] // skillId -> latest confidence (1-10)
        let goalDUPR: ConfidenceBenchmark.TargetDUPR
        let recentHistory: [FocusHistoryEntry]
    }

    struct Output {
        let primary: RecommendedFocus?
        let alternative: RecommendedFocus?
        let bottleneckPillar: SkillPillar?
    }

    // MARK: - Main Entry Point

    static func recommend(input: Input) -> Output {
        let activeSkills = input.skills.filter { $0.status == .active }
        guard !activeSkills.isEmpty else {
            return Output(primary: nil, alternative: nil, bottleneckPillar: nil)
        }

        // Build skill gap info
        let gapInfos = buildGapInfos(skills: activeSkills, confidences: input.confidences, targetDUPR: input.goalDUPR)

        guard !gapInfos.isEmpty else {
            return Output(primary: nil, alternative: nil, bottleneckPillar: nil)
        }

        // Stage 1: Bottleneck pillar
        let bottleneckPillar = computeBottleneckPillar(gapInfos: gapInfos, targetDUPR: input.goalDUPR)

        // Stage 2: Bottleneck skill within pillar
        let primarySkill = computeBottleneckSkill(
            gapInfos: gapInfos,
            pillar: bottleneckPillar,
            confidences: input.confidences,
            history: input.recentHistory
        )

        // Alternative: best skill from a different pillar
        let altPillar = computeSecondaryPillar(
            gapInfos: gapInfos,
            excludePillar: bottleneckPillar,
            targetDUPR: input.goalDUPR
        )

        let altSkill: SkillGapInfo?
        if let altPillar {
            altSkill = computeBottleneckSkill(
                gapInfos: gapInfos,
                pillar: altPillar,
                confidences: input.confidences,
                history: input.recentHistory
            )
        } else {
            // Fall back to second-best in same pillar
            let samePillarSkills = gapInfos
                .filter { $0.skill.pillar == bottleneckPillar && $0.skill.id != primarySkill?.skill.id }
                .sorted { $0.gap > $1.gap }
            altSkill = samePillarSkills.first
        }

        let primary = primarySkill.map { info in
            RecommendedFocus(
                skill: info.skill,
                pillar: info.skill.pillar,
                sessionType: nextSessionType(for: info.skill.id, history: input.recentHistory),
                currentConfidence: info.current,
                targetConfidence: info.target,
                reason: buildReason(info: info, pillar: bottleneckPillar)
            )
        }

        let alternative = altSkill.map { info in
            RecommendedFocus(
                skill: info.skill,
                pillar: info.skill.pillar,
                sessionType: nextSessionType(for: info.skill.id, history: input.recentHistory),
                currentConfidence: info.current,
                targetConfidence: info.target,
                reason: "Alternative: \(info.skill.pillar.displayName) focus"
            )
        }

        return Output(primary: primary, alternative: alternative, bottleneckPillar: bottleneckPillar)
    }

    // MARK: - Stage 1: Bottleneck Pillar

    /// Find the pillar with the highest weighted total gap.
    static func computeBottleneckPillar(
        gapInfos: [SkillGapInfo],
        targetDUPR: ConfidenceBenchmark.TargetDUPR
    ) -> SkillPillar {
        var pillarScores: [SkillPillar: Double] = [:]

        for pillar in SkillPillar.allCases {
            let pillarGaps = gapInfos.filter { $0.skill.pillar == pillar }
            guard !pillarGaps.isEmpty else { continue }

            let totalGap = pillarGaps.reduce(0) { $0 + $1.gap }
            let weight = ConfidenceBenchmark.pillarWeight(pillar: pillar, targetDUPR: targetDUPR)
            pillarScores[pillar] = Double(totalGap) * weight
        }

        return pillarScores.max(by: { $0.value < $1.value })?.key ?? .consistency
    }

    // MARK: - Stage 2: Bottleneck Skill

    /// Find the highest-priority skill within a pillar.
    /// Priority = gap * dependencyWeight * recencyPenalty * varietyBonus
    static func computeBottleneckSkill(
        gapInfos: [SkillGapInfo],
        pillar: SkillPillar,
        confidences: [UUID: Int],
        history: [FocusHistoryEntry]
    ) -> SkillGapInfo? {
        let pillarSkills = gapInfos.filter { $0.skill.pillar == pillar && $0.gap > 0 }
        guard !pillarSkills.isEmpty else { return nil }

        // Build canonicalId -> confidence map for prerequisite checks
        var canonicalConfidences: [String: Int] = [:]
        for info in gapInfos {
            if let cid = info.skill.canonicalId {
                canonicalConfidences[cid] = info.current
            }
        }

        let scored = pillarSkills.map { info -> (info: SkillGapInfo, score: Double) in
            var score = Double(info.gap)

            // Dependency weight: skills that unlock others get a boost
            if let cid = info.skill.canonicalId {
                let dependents = SkillPrerequisite.all.filter { $0.requiredSkillCanonicalId == cid }
                if !dependents.isEmpty {
                    score *= 1.3 // Prerequisite skills are more important
                }

                // Skip locked skills (prerequisites not met)
                if SkillPrerequisite.isLocked(canonicalId: cid, confidences: canonicalConfidences) {
                    score *= 0.1 // Heavily penalize locked skills
                }
            }

            // Recency penalty: avoid recommending the same skill repeatedly
            let recentForSkill = history.filter { $0.skillId == info.skill.id }
            if let lastDate = recentForSkill.first?.date {
                let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
                if daysSince < 2 {
                    score *= 0.5 // Just did this skill recently
                } else if daysSince < 4 {
                    score *= 0.8
                }
            }

            // Variety bonus: prefer skills not recently focused
            let focusCount = recentForSkill.prefix(10).count
            if focusCount == 0 {
                score *= 1.2 // Never focused before
            }

            return (info: info, score: score)
        }

        return scored.max(by: { $0.score < $1.score })?.info
    }

    // MARK: - Helpers

    private static func computeSecondaryPillar(
        gapInfos: [SkillGapInfo],
        excludePillar: SkillPillar,
        targetDUPR: ConfidenceBenchmark.TargetDUPR
    ) -> SkillPillar? {
        var pillarScores: [SkillPillar: Double] = [:]

        for pillar in SkillPillar.allCases where pillar != excludePillar {
            let pillarGaps = gapInfos.filter { $0.skill.pillar == pillar && $0.gap > 0 }
            guard !pillarGaps.isEmpty else { continue }

            let totalGap = pillarGaps.reduce(0) { $0 + $1.gap }
            let weight = ConfidenceBenchmark.pillarWeight(pillar: pillar, targetDUPR: targetDUPR)
            pillarScores[pillar] = Double(totalGap) * weight
        }

        return pillarScores.max(by: { $0.value < $1.value })?.key
    }

    static func buildGapInfos(
        skills: [Skill],
        confidences: [UUID: Int],
        targetDUPR: ConfidenceBenchmark.TargetDUPR
    ) -> [SkillGapInfo] {
        skills.compactMap { skill in
            let current = confidences[skill.id] ?? 1
            let target: Int
            if let canonicalId = skill.canonicalId,
               let t = ConfidenceBenchmark.target(canonicalId: canonicalId, targetDUPR: targetDUPR) {
                target = t
            } else {
                target = 5
            }
            let gap = max(0, target - current)
            return SkillGapInfo(skill: skill, current: current, target: target, gap: gap)
        }
    }

    /// Determine the next session type in the Learn -> Practice -> Apply -> Play cycle.
    private static func nextSessionType(
        for skillId: UUID,
        history: [FocusHistoryEntry]
    ) -> SessionType {
        let recentForSkill = history
            .filter { $0.skillId == skillId && $0.wasCompleted }
            .sorted { $0.date > $1.date }

        guard let last = recentForSkill.first else {
            return .learn
        }

        switch last.sessionType {
        case .learn: return .practice
        case .practice: return .apply
        case .apply: return .play
        case .play: return .learn
        default: return .learn
        }
    }

    private static func buildReason(info: SkillGapInfo, pillar: SkillPillar) -> String {
        if info.gap >= 4 {
            return "Your \(pillar.displayName) game needs the most work — \(info.skill.name) has the biggest gap."
        } else if info.gap >= 2 {
            return "\(info.skill.name) is close to target. A focused session can close the gap."
        } else {
            return "Fine-tuning \(info.skill.name) will level up your \(pillar.displayName)."
        }
    }
}

// MARK: - Supporting Types

struct SkillGapInfo {
    let skill: Skill
    let current: Int
    let target: Int
    let gap: Int
}
