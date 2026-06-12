import Foundation

// MARK: - Input / Output

struct ScheduleEngineInput {
    let profile: PlayerProfile
    let focusSkills: [FocusSkillEntry]
    let skillRatings: [UUID: Int]
    let availableDayTypes: [Int: String]
    let sessionDurationMinutes: Int
    let catalog: [CatalogDrill]
}

struct ScheduleEngineOutput {
    let program: Program
    let sessions: [ProgramSession]
    let drills: [UUID: [ProgramDrill]]
}

// MARK: - Engine

enum ScheduleEngine {

    // MARK: - Public

    static func generate(input: ScheduleEngineInput) -> ScheduleEngineOutput {
        let profile = input.profile
        let focusSkills = input.focusSkills
        let catalog = input.catalog
        let sessionDuration = input.sessionDurationMinutes

        // Step 1-3: Compute per-skill scores
        let skillScores = computeSkillScores(
            focusSkills: focusSkills,
            skillRatings: input.skillRatings,
            profile: profile
        )

        // Step 4: Convert scores to minute budgets
        let drillDays = input.availableDayTypes.values.filter { $0 == "Drill" }.count
        let totalDrillMinutes = drillDays * sessionDuration * 4 // 4 weeks
        let minuteBudgets = allocateMinutes(
            skillScores: skillScores,
            totalMinutes: totalDrillMinutes,
            catalog: catalog
        )

        // Build 4 weeks of drill selections with weekly progression
        var allWeekDrills: [[SelectedDrill]] = []
        for week in 1...4 {
            var weekDrills: [SelectedDrill] = []
            for entry in skillScores {
                let weekMinutes = (minuteBudgets[entry.skillId] ?? 0) / 4
                guard weekMinutes > 0 else { continue }
                let selected = selectDrills(
                    forCategory: entry.categoryRaw,
                    minuteBudget: weekMinutes,
                    week: week,
                    profile: profile,
                    catalog: catalog,
                    struggleAreas: profile.struggleAreas ?? [],
                    skillName: entry.skillName
                )
                weekDrills.append(contentsOf: selected)
            }
            allWeekDrills.append(weekDrills)
        }

        // Assemble sessions
        let programId = UUID()
        var sessions: [ProgramSession] = []
        var drillsMap: [UUID: [ProgramDrill]] = [:]
        var sessionCounter = 0

        let sortedDayTypes = input.availableDayTypes.sorted { $0.key < $1.key }

        for week in 1...4 {
            let weekDrills = allWeekDrills[week - 1]
            var drillQueue = weekDrills
            let topFocusCategory = skillScores.first?.categoryRaw ?? "dinking"
            let topFocusName = skillScores.first?.skillName ?? "General"
            let topStruggle = (profile.struggleAreas ?? []).first ?? "Execution"

            for (dayIndex, dayType) in sortedDayTypes {
                guard dayType != "Rest" else { continue }
                sessionCounter += 1

                if dayType == "Drill" {
                    // Distribute drills across drill-day sessions
                    let drillsPerSession = max(1, drillQueue.count / max(1, drillDays))
                    let taken = Array(drillQueue.prefix(drillsPerSession))
                    drillQueue = Array(drillQueue.dropFirst(taken.count))

                    let focusLabel = taken.first?.skillName ?? topFocusName
                    let session = ProgramSession(
                        programId: programId,
                        weekNumber: week,
                        sessionNumber: sessionCounter,
                        title: "Week \(week) — \(focusLabel) Focus",
                        focus: "\(focusLabel) drills",
                        estimatedMinutes: min(sessionDuration, taken.reduce(0) { $0 + $1.durationMinutes }),
                        status: sessions.isEmpty ? .available : .locked
                    )
                    sessions.append(session)

                    let programDrills = taken.enumerated().map { order, sel in
                        ProgramDrill(
                            programSessionId: session.id,
                            name: sel.name,
                            drillDescription: sel.description,
                            durationMinutes: sel.durationMinutes,
                            targetReps: sel.targetReps,
                            equipment: sel.equipment,
                            playerCount: sel.playerCount,
                            displayOrder: order
                        )
                    }
                    drillsMap[session.id] = programDrills

                } else {
                    // Game day: 1 warm-up drill + 1 focused game play
                    let warmupDrill = selectWarmupDrill(
                        forCategory: topFocusCategory,
                        profile: profile,
                        catalog: catalog
                    )

                    let warmupMinutes = warmupDrill?.durationMinutes ?? 5
                    let gameMinutes = max(10, sessionDuration - warmupMinutes)

                    let session = ProgramSession(
                        programId: programId,
                        weekNumber: week,
                        sessionNumber: sessionCounter,
                        title: "Week \(week) — Game Day",
                        focus: "Game play with \(topFocusName.lowercased()) focus",
                        estimatedMinutes: sessionDuration,
                        status: sessions.isEmpty ? .available : .locked
                    )
                    sessions.append(session)

                    var gameDrills: [ProgramDrill] = []
                    if let wu = warmupDrill {
                        gameDrills.append(ProgramDrill(
                            programSessionId: session.id,
                            name: wu.name,
                            drillDescription: wu.description,
                            durationMinutes: wu.durationMinutes,
                            targetReps: wu.targetReps,
                            equipment: wu.equipment,
                            playerCount: wu.playerCount,
                            displayOrder: 0
                        ))
                    }
                    gameDrills.append(ProgramDrill(
                        programSessionId: session.id,
                        name: "Focused Game Play",
                        drillDescription: "Play games focusing on \(topStruggle.lowercased()). Apply the skills you've been drilling this week in live play. Track how often you execute successfully.",
                        durationMinutes: gameMinutes,
                        targetReps: 1,
                        equipment: "Balls",
                        playerCount: 2,
                        displayOrder: gameDrills.count
                    ))
                    drillsMap[session.id] = gameDrills
                }
            }

            // Reset session counter per week is not needed — sessionNumber is global
        }

        // Flush any remaining drill queue drills into the last drill session
        // (edge case: more drills than sessions)

        // Build program metadata
        let topSkillName = skillScores.first?.skillName ?? "General"
        let timelineLabel = programTimelineLabel(profile.targetTimeline)
        let skillSummary = skillScores.prefix(3).map { entry in
            let pct = minuteBudgets[entry.skillId].map { totalDrillMinutes > 0 ? Int(Double($0) / Double(totalDrillMinutes) * 100) : 0 } ?? 0
            return "\(entry.skillName) (\(pct)%)"
        }.joined(separator: ", ")

        let nonRestDays = input.availableDayTypes.values.filter { $0 != "Rest" }.count

        let program = Program(
            id: programId,
            name: "\(topSkillName) \(timelineLabel)",
            programDescription: "4-week program: \(skillSummary). Personalized to your skill level and goals.",
            totalWeeks: 4,
            sessionsPerWeek: nonRestDays,
            skillFocus: skillScores.map(\.skillName).joined(separator: ", "),
            source: .generated
        )

        return ScheduleEngineOutput(
            program: program,
            sessions: sessions,
            drills: drillsMap
        )
    }

    // MARK: - Skill Scoring

    private struct ScoredSkill {
        let skillId: UUID
        let skillName: String
        let categoryRaw: String
        let score: Double
    }

    private static func computeSkillScores(
        focusSkills: [FocusSkillEntry],
        skillRatings: [UUID: Int],
        profile: PlayerProfile
    ) -> [ScoredSkill] {
        let duprRange = DUPRRange.from(profileString: profile.duprRange)
        let injuries = Set(profile.injuries ?? [])

        let priorityWeights: [Int: Double] = [0: 1.0, 1: 0.6, 2: 0.35]

        var scored: [ScoredSkill] = []

        for entry in focusSkills {
            let category = SkillCategory(rawValue: entry.categoryRaw)
            let benchmark: Int
            if let cat = category, let range = duprRange {
                benchmark = SkillBenchmark.benchmarks[cat]?[range] ?? 50
            } else {
                benchmark = 50
            }

            let currentRating = skillRatings[entry.id] ?? entry.startingRating ?? 0
            let gap = max(0, Double(benchmark - currentRating)) / 100.0
            let priorityWeight = priorityWeights[entry.priorityIndex] ?? 0.2

            var score = gap * 0.6 + priorityWeight * 0.4

            // Reduce score if drills would aggravate injury
            if wouldAggravateInjury(category: entry.categoryRaw, injuries: injuries) {
                score *= 0.3
            }

            scored.append(ScoredSkill(
                skillId: entry.id,
                skillName: entry.name,
                categoryRaw: entry.categoryRaw,
                score: score
            ))
        }

        // If no focus skills, create even distribution from all categories
        if scored.isEmpty {
            for (index, category) in SkillCategory.allCases.enumerated() {
                scored.append(ScoredSkill(
                    skillId: UUID(),
                    skillName: category.displayName,
                    categoryRaw: category.rawValue,
                    score: 1.0 / Double(SkillCategory.allCases.count)
                ))
                if index >= 2 { break } // cap at 3
            }
        }

        return scored.sorted { $0.score > $1.score }
    }

    // MARK: - Minute Allocation

    private static func allocateMinutes(
        skillScores: [ScoredSkill],
        totalMinutes: Int,
        catalog: [CatalogDrill]
    ) -> [UUID: Int] {
        let sumScores = skillScores.reduce(0.0) { $0 + $1.score }
        guard sumScores > 0, totalMinutes > 0 else {
            return Dictionary(uniqueKeysWithValues: skillScores.map { ($0.skillId, 0) })
        }

        // Find minimum drill duration for the floor
        let minDrillDuration = catalog.map(\.durationMinutes).min() ?? 5

        var budgets: [UUID: Int] = [:]
        for entry in skillScores {
            let raw = Int(Double(totalMinutes) * (entry.score / sumScores))
            budgets[entry.skillId] = max(raw, minDrillDuration)
        }
        return budgets
    }

    // MARK: - Drill Selection

    private struct SelectedDrill {
        let name: String
        let description: String
        let durationMinutes: Int
        let targetReps: Int
        let equipment: String
        let playerCount: Int
        let skillName: String
    }

    private static func selectDrills(
        forCategory category: String,
        minuteBudget: Int,
        week: Int,
        profile: PlayerProfile,
        catalog: [CatalogDrill],
        struggleAreas: [String],
        skillName: String
    ) -> [SelectedDrill] {
        let playerTier = playerSkillTier(from: profile)
        let soloOnly = profile.partnerAccess == "Solo only"
        let injuries = Set(profile.injuries ?? [])

        // Filter catalog
        var candidates = catalog.filter { drill in
            guard drill.skillCategory == category else { return false }
            guard isDifficultyCompatible(drill.difficultyTier, playerTier: playerTier, week: week) else { return false }
            if soloOnly && drill.playerCount > 1 { return false }
            if hasInjuryConflict(drill: drill, injuries: injuries) { return false }
            if let wp = drill.weekProgression, wp != week { return false }
            return true
        }

        // Sort by drill type match to struggle areas, then week specificity, then id
        let struggleTypes = mapStruggleAreasToTypes(struggleAreas)
        let weekEmphasis = weekTypeEmphasis(week)

        candidates.sort { a, b in
            let aTypeScore = typeMatchScore(a.drillType, struggleTypes: struggleTypes, weekEmphasis: weekEmphasis)
            let bTypeScore = typeMatchScore(b.drillType, struggleTypes: struggleTypes, weekEmphasis: weekEmphasis)
            if aTypeScore != bTypeScore { return aTypeScore > bTypeScore }

            let aWeekSpecific = a.weekProgression != nil
            let bWeekSpecific = b.weekProgression != nil
            if aWeekSpecific != bWeekSpecific { return aWeekSpecific }

            return a.id < b.id
        }

        // Greedy pack
        var selected: [SelectedDrill] = []
        var remaining = minuteBudget
        var usedIds: Set<String> = []

        for drill in candidates {
            guard remaining > 0 else { break }
            usedIds.insert(drill.id)

            let repsMultiplier = weekRepsMultiplier(week)
            let adjustedReps = max(1, Int(Double(drill.targetReps) * repsMultiplier))

            selected.append(SelectedDrill(
                name: drill.name,
                description: drill.description,
                durationMinutes: drill.durationMinutes,
                targetReps: adjustedReps,
                equipment: drill.equipment,
                playerCount: drill.playerCount,
                skillName: skillName
            ))
            remaining -= drill.durationMinutes
        }

        // If insufficient drills, allow repeats with +50% reps
        if remaining > 0 && !candidates.isEmpty {
            var repeatIndex = 0
            while remaining > 0 && repeatIndex < candidates.count {
                let drill = candidates[repeatIndex]
                let repsMultiplier = weekRepsMultiplier(week)
                let adjustedReps = max(1, Int(Double(drill.targetReps) * repsMultiplier * 1.5))

                selected.append(SelectedDrill(
                    name: drill.name,
                    description: drill.description,
                    durationMinutes: drill.durationMinutes,
                    targetReps: adjustedReps,
                    equipment: drill.equipment,
                    playerCount: drill.playerCount,
                    skillName: skillName
                ))
                remaining -= drill.durationMinutes
                repeatIndex += 1
            }
        }

        return selected
    }

    private static func selectWarmupDrill(
        forCategory category: String,
        profile: PlayerProfile,
        catalog: [CatalogDrill]
    ) -> CatalogDrill? {
        let soloOnly = profile.partnerAccess == "Solo only"
        let injuries = Set(profile.injuries ?? [])

        let candidates = catalog.filter { drill in
            guard drill.skillCategory == category else { return false }
            guard drill.durationMinutes <= 10 else { return false }
            guard drill.difficultyTier == "beginner" || drill.difficultyTier == "intermediate" else { return false }
            if soloOnly && drill.playerCount > 1 { return false }
            if hasInjuryConflict(drill: drill, injuries: injuries) { return false }
            return true
        }.sorted { $0.id < $1.id }

        return candidates.first
    }

    // MARK: - Helpers

    private static func playerSkillTier(from profile: PlayerProfile) -> String {
        guard let duprRange = DUPRRange.from(profileString: profile.duprRange) else {
            return "intermediate"
        }
        switch duprRange {
        case .beginner_2_0_3_0:
            return "beginner"
        case .intermediate_3_0_3_5, .intermediate_3_5_4_0:
            return "intermediate"
        case .advanced_4_0_4_5, .advanced_4_5_5_0, .pro_5_0_plus:
            return "advanced"
        }
    }

    private static func isDifficultyCompatible(_ drillTier: String, playerTier: String, week: Int) -> Bool {
        let tierOrder = ["beginner": 0, "intermediate": 1, "advanced": 2]
        let drillLevel = tierOrder[drillTier] ?? 1
        let playerLevel = tierOrder[playerTier] ?? 1

        // Same tier is always OK
        if drillLevel == playerLevel { return true }
        // One tier below is OK
        if drillLevel == playerLevel - 1 { return true }
        // One tier above: only in weeks 3-4 (progression)
        if drillLevel == playerLevel + 1 && week >= 3 { return true }

        return false
    }

    private static func wouldAggravateInjury(category: String, injuries: Set<String>) -> Bool {
        if injuries.isEmpty || injuries.contains("None") { return false }
        let categoryInjuryMap: [String: Set<String>] = [
            "offense": ["Shoulder"],
            "serves": ["Shoulder", "Wrist"],
            "drives": ["Wrist", "Shoulder"],
            "defense": ["Knee", "Back"],
            "drops": ["Wrist"],
        ]
        guard let relevantInjuries = categoryInjuryMap[category] else { return false }
        return !relevantInjuries.isDisjoint(with: injuries)
    }

    private static func hasInjuryConflict(drill: CatalogDrill, injuries: Set<String>) -> Bool {
        if injuries.isEmpty || injuries.contains("None") { return false }
        let injuryTagMap: [String: Set<String>] = [
            "Shoulder": ["shoulder", "overhead"],
            "Knee": ["knee", "lateral_movement", "jumping"],
            "Back": ["back"],
            "Wrist": ["wrist"],
        ]
        let drillTags = Set(drill.tags)
        for injury in injuries {
            if let blockedTags = injuryTagMap[injury] {
                if !blockedTags.isDisjoint(with: drillTags) {
                    return true
                }
            }
        }
        return false
    }

    private static func mapStruggleAreasToTypes(_ areas: [String]) -> Set<String> {
        var types: Set<String> = []
        for area in areas {
            switch area {
            case "Execution": types.insert("execution")
            case "Transfer to games": types.insert("game_transfer")
            case "Decision-making": types.insert("decision_making")
            case "Pressure": types.insert("pressure")
            default: break
            }
        }
        return types
    }

    private static func weekTypeEmphasis(_ week: Int) -> [String: Double] {
        switch week {
        case 1: return ["execution": 2.0, "game_transfer": 1.0, "decision_making": 1.0, "pressure": 0.5]
        case 2: return ["execution": 1.5, "game_transfer": 1.2, "decision_making": 1.2, "pressure": 0.8]
        case 3: return ["execution": 1.0, "game_transfer": 1.5, "decision_making": 1.5, "pressure": 1.5]
        case 4: return ["execution": 0.8, "game_transfer": 2.0, "decision_making": 1.5, "pressure": 2.0]
        default: return ["execution": 1.0, "game_transfer": 1.0, "decision_making": 1.0, "pressure": 1.0]
        }
    }

    private static func typeMatchScore(_ drillType: String, struggleTypes: Set<String>, weekEmphasis: [String: Double]) -> Double {
        var score = weekEmphasis[drillType] ?? 1.0
        if struggleTypes.contains(drillType) {
            score += 1.0
        }
        return score
    }

    private static func weekRepsMultiplier(_ week: Int) -> Double {
        switch week {
        case 1: return 0.8
        case 2: return 1.0
        case 3: return 1.1
        case 4: return 1.3
        default: return 1.0
        }
    }

    private static func programTimelineLabel(_ timeline: String?) -> String {
        switch timeline {
        case "Tournament coming up": return "Tournament Prep"
        case "Hit a DUPR milestone": return "DUPR Push"
        case "General improvement": return "Development"
        default: return "Training"
        }
    }
}
