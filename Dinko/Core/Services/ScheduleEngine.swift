import Foundation

// MARK: - Input / Output

struct ScheduleEngineInput {
    let profile: PlayerProfile
    let focusSkills: [FocusSkillEntry]
    let skillRatings: [UUID: Int]
    let availableDayTypes: [Int: String]
    let sessionDurationMinutes: Int
}

struct ScheduleEngineOutput {
    let program: Program
    let sessions: [ProgramSession]
}

// MARK: - Engine

enum ScheduleEngine {

    // MARK: - Public

    static func generate(input: ScheduleEngineInput) -> ScheduleEngineOutput {
        let profile = input.profile
        let focusSkills = input.focusSkills
        let sessionDuration = input.sessionDurationMinutes

        // Compute per-skill scores for rotation and naming
        let skillScores = computeSkillScores(
            focusSkills: focusSkills,
            skillRatings: input.skillRatings,
            profile: profile
        )

        // Assemble sessions — day types only, no drills
        let programId = UUID()
        var sessions: [ProgramSession] = []
        var sessionCounter = 0

        let sortedDayTypes = input.availableDayTypes.sorted { $0.key < $1.key }

        // Identify drill days sorted by day index for skill rotation
        let drillDayIndices = sortedDayTypes.filter { $0.value == "Drill" }.map(\.key)

        for week in 1...4 {
            let topFocusName = skillScores.first?.skillName ?? "General"

            for (dayIndex, dayType) in sortedDayTypes {
                guard dayType != "Rest" else { continue }
                sessionCounter += 1

                if dayType == "Drill" {
                    // Rotate skills across drill days
                    let drillDayOffset = drillDayIndices.firstIndex(of: dayIndex) ?? 0
                    let primarySkill = skillScores.isEmpty
                        ? nil
                        : skillScores[drillDayOffset % skillScores.count]
                    let focusLabel = primarySkill?.skillName ?? topFocusName

                    let session = ProgramSession(
                        programId: programId,
                        weekNumber: week,
                        sessionNumber: sessionCounter,
                        title: "\(focusLabel) Day",
                        focus: focusLabel,
                        estimatedMinutes: sessionDuration,
                        scheduledDayOfWeek: dayIndex,
                        status: sessions.isEmpty ? .available : .locked
                    )
                    sessions.append(session)

                } else {
                    // Game day
                    let session = ProgramSession(
                        programId: programId,
                        weekNumber: week,
                        sessionNumber: sessionCounter,
                        title: "Game Day",
                        focus: "Game play with \(topFocusName.lowercased()) focus",
                        estimatedMinutes: sessionDuration,
                        scheduledDayOfWeek: dayIndex,
                        status: sessions.isEmpty ? .available : .locked
                    )
                    sessions.append(session)
                }
            }
        }

        // Build program metadata
        let topSkillName = skillScores.first?.skillName ?? "General"
        let timelineLabel = programTimelineLabel(profile.targetTimeline)
        let skillSummary = skillScores.prefix(3).map(\.skillName).joined(separator: ", ")

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
            sessions: sessions
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

    // MARK: - Helpers

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

    private static func programTimelineLabel(_ timeline: String?) -> String {
        switch timeline {
        case "Tournament coming up": return "Tournament Prep"
        case "Hit a DUPR milestone": return "DUPR Push"
        case "General improvement": return "Development"
        default: return "Training"
        }
    }
}
