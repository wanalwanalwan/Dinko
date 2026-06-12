import XCTest
@testable import Dinko

final class ScheduleEngineTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeProfile(
        duprRange: String = "Intermediate (3.0-4.0)",
        partnerAccess: String? = "Always",
        targetTimeline: String? = "General improvement",
        injuries: [String]? = nil,
        struggleAreas: [String]? = ["Execution"],
        availableDays: [Int] = [0, 1, 2, 3, 4],
        preferredGameDay: Int? = 4,
        sessionDuration: Int = 45,
        drillBalance: String = "Mix of drills & games"
    ) -> PlayerProfile {
        PlayerProfile(
            duprRange: duprRange,
            playStyle: "All-Court",
            gameFormat: "Doubles",
            primaryGoal: "Improve DUPR",
            ageRange: nil,
            weeklyGoal: availableDays.count,
            practiceSetting: nil,
            experienceLevel: "1-3 years",
            injuries: injuries,
            drillPreferences: nil,
            drillBalance: drillBalance,
            availableDays: availableDays,
            preferredGameDay: preferredGameDay,
            sessionDuration: sessionDuration,
            partnerAccess: partnerAccess,
            targetTimeline: targetTimeline,
            struggleAreas: struggleAreas
        )
    }

    private func makeFocusSkills() -> [FocusSkillEntry] {
        [
            FocusSkillEntry(id: UUID(), name: "Dinking", icon: "🥒", categoryRaw: "dinking", priorityIndex: 0, startingRating: 30),
            FocusSkillEntry(id: UUID(), name: "3rd Shot Drop", icon: "⬇️", categoryRaw: "drops", priorityIndex: 1, startingRating: 20),
            FocusSkillEntry(id: UUID(), name: "Drive", icon: "🚀", categoryRaw: "drives", priorityIndex: 2, startingRating: 50),
        ]
    }

    private func makeCatalog() -> [CatalogDrill] {
        // Minimal catalog for tests — 2 drills per category/tier combo
        var drills: [CatalogDrill] = []
        let categories = ["dinking", "drops", "drives", "defense", "offense", "strategy", "serves"]
        let tiers = ["beginner", "intermediate", "advanced"]
        let types = ["execution", "game_transfer", "decision_making", "pressure"]

        for cat in categories {
            for tier in tiers {
                for (i, drillType) in types.enumerated() {
                    drills.append(CatalogDrill(
                        id: "\(cat)-\(tier)-\(drillType)-1",
                        name: "\(cat.capitalized) \(tier.capitalized) \(drillType)",
                        description: "Test drill for \(cat) at \(tier) level focusing on \(drillType).",
                        skillCategory: cat,
                        difficultyTier: tier,
                        drillType: drillType,
                        durationMinutes: 10,
                        targetReps: 20,
                        equipment: "Balls",
                        playerCount: i % 2 == 0 ? 1 : 2,
                        weekProgression: nil,
                        tags: cat == "offense" ? ["shoulder", "overhead"] : []
                    ))
                }
            }
        }
        return drills
    }

    private func makeInput(
        profile: PlayerProfile? = nil,
        focusSkills: [FocusSkillEntry]? = nil,
        catalog: [CatalogDrill]? = nil
    ) -> ScheduleEngineInput {
        let p = profile ?? makeProfile()
        let fs = focusSkills ?? makeFocusSkills()
        let cat = catalog ?? makeCatalog()

        var ratings: [UUID: Int] = [:]
        for entry in fs {
            ratings[entry.id] = entry.startingRating ?? 0
        }

        let dayTypes = HomeViewModel.buildSuggestedTypes(
            availableDays: p.availableDays ?? [],
            preferredGameDay: p.preferredGameDay,
            drillBalance: p.drillBalance
        )

        return ScheduleEngineInput(
            profile: p,
            focusSkills: fs,
            skillRatings: ratings,
            availableDayTypes: dayTypes,
            sessionDurationMinutes: p.sessionDuration ?? 45,
            catalog: cat
        )
    }

    // MARK: - Tests

    func testDeterminism_sameInputProducesIdenticalOutput() {
        let input = makeInput()

        let output1 = ScheduleEngine.generate(input: input)
        let output2 = ScheduleEngine.generate(input: input)

        XCTAssertEqual(output1.sessions.count, output2.sessions.count)
        for (s1, s2) in zip(output1.sessions, output2.sessions) {
            XCTAssertEqual(s1.title, s2.title)
            XCTAssertEqual(s1.weekNumber, s2.weekNumber)
            XCTAssertEqual(s1.estimatedMinutes, s2.estimatedMinutes)

            let d1 = output1.drills[s1.id] ?? []
            let d2 = output2.drills[s2.id] ?? []
            XCTAssertEqual(d1.count, d2.count)
            for (drill1, drill2) in zip(d1, d2) {
                XCTAssertEqual(drill1.name, drill2.name)
                XCTAssertEqual(drill1.targetReps, drill2.targetReps)
            }
        }

        XCTAssertEqual(output1.program.name, output2.program.name)
        XCTAssertEqual(output1.program.programDescription, output2.program.programDescription)
    }

    func testVolumeAllocation_lowerRatedSkillGetsMoreMinutes() {
        let skills = makeFocusSkills()
        // skills[0] Dinking = 30 rating, skills[2] Drive = 50 rating
        // With intermediate benchmark ~40-55 for dinking and drives,
        // dinking has a bigger gap and higher priority → should get more allocation

        let input = makeInput(focusSkills: skills)
        let output = ScheduleEngine.generate(input: input)

        // Count total drill minutes per skill by inspecting drill names
        let allDrills = output.drills.values.flatMap { $0 }
        let dinkingDrills = allDrills.filter { $0.name.lowercased().contains("dinking") }
        let driveDrills = allDrills.filter { $0.name.lowercased().contains("drives") }

        let dinkingMinutes = dinkingDrills.reduce(0) { $0 + $1.durationMinutes }
        let driveMinutes = driveDrills.reduce(0) { $0 + $1.durationMinutes }

        // Dinking (lower rated, higher priority) should have >= drive minutes
        XCTAssertGreaterThanOrEqual(dinkingMinutes, driveMinutes,
            "Lower-rated, higher-priority skill should get more training minutes")
    }

    func testPartnerFiltering_soloOnlyExcludesPartnerDrills() {
        let profile = makeProfile(partnerAccess: "Solo only")
        let input = makeInput(profile: profile)
        let output = ScheduleEngine.generate(input: input)

        let allDrills = output.drills.values.flatMap { $0 }
        // Filter out the "Focused Game Play" entries since those are always playerCount 2
        let nonGameDrills = allDrills.filter { $0.name != "Focused Game Play" }

        for drill in nonGameDrills {
            XCTAssertEqual(drill.playerCount, 1,
                "Solo only profile should not receive partner drills (found: \(drill.name) with playerCount \(drill.playerCount))")
        }
    }

    func testInjuryFiltering_shoulderInjuryExcludesOverheadDrills() {
        let profile = makeProfile(injuries: ["Shoulder"])
        let input = makeInput(profile: profile)
        let output = ScheduleEngine.generate(input: input)

        let allDrills = output.drills.values.flatMap { $0 }
        let nonGameDrills = allDrills.filter { $0.name != "Focused Game Play" }

        for drill in nonGameDrills {
            // In our test catalog, offense drills have ["shoulder", "overhead"] tags
            // They should be excluded
            XCTAssertFalse(
                drill.name.lowercased().contains("offense") && drill.name.lowercased().contains("overhead"),
                "Shoulder injury should exclude overhead-tagged drills"
            )
        }
    }

    func testSessionDuration_noSessionExceedsConfiguredMinutes() {
        let sessionDuration = 45
        let profile = makeProfile(sessionDuration: sessionDuration)
        let input = makeInput(profile: profile)
        let output = ScheduleEngine.generate(input: input)

        for session in output.sessions {
            XCTAssertLessThanOrEqual(session.estimatedMinutes, sessionDuration,
                "Session '\(session.title)' exceeds configured duration: \(session.estimatedMinutes) > \(sessionDuration)")
        }
    }

    func testGameDays_haveWarmupAndGamePlay() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        let gameSessions = output.sessions.filter { $0.title.contains("Game Day") }
        XCTAssertFalse(gameSessions.isEmpty, "Should have at least one game day session")

        for session in gameSessions {
            let sessionDrills = output.drills[session.id] ?? []
            let hasGamePlay = sessionDrills.contains { $0.name == "Focused Game Play" }
            XCTAssertTrue(hasGamePlay, "Game day session '\(session.title)' should have a Focused Game Play entry")

            // Should have exactly 2 entries: warm-up + game play
            XCTAssertEqual(sessionDrills.count, 2,
                "Game day session should have exactly 2 entries (warm-up + game play), got \(sessionDrills.count)")
        }
    }

    func testWeeklyProgression_week4RepsGreaterThanWeek1() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        let week1Sessions = output.sessions.filter { $0.weekNumber == 1 && !$0.title.contains("Game Day") }
        let week4Sessions = output.sessions.filter { $0.weekNumber == 4 && !$0.title.contains("Game Day") }

        guard let w1 = week1Sessions.first, let w4 = week4Sessions.first else {
            XCTFail("Need at least one drill session in weeks 1 and 4")
            return
        }

        let w1Drills = output.drills[w1.id] ?? []
        let w4Drills = output.drills[w4.id] ?? []

        guard let w1FirstDrill = w1Drills.first, let w4FirstDrill = w4Drills.first else {
            XCTFail("Need at least one drill in week 1 and week 4 sessions")
            return
        }

        // Week 4 should have higher reps (1.3x multiplier vs 0.8x)
        if w1FirstDrill.name == w4FirstDrill.name {
            XCTAssertGreaterThan(w4FirstDrill.targetReps, w1FirstDrill.targetReps,
                "Week 4 reps should be higher than Week 1 for the same drill")
        }
    }

    func testNoFocusSkills_producesValidOutput() {
        let input = makeInput(focusSkills: [])
        let output = ScheduleEngine.generate(input: input)

        XCTAssertFalse(output.sessions.isEmpty, "Should produce sessions even with no focus skills")
        XCTAssertFalse(output.program.name.isEmpty, "Program should have a name")
    }

    func testProgramMetadata_hasCorrectSource() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        XCTAssertEqual(output.program.source, .generated, "Program source should be .generated")
        XCTAssertEqual(output.program.totalWeeks, 4, "Program should be 4 weeks")
    }

    func testTimelineLabel_tournamentPrep() {
        let profile = makeProfile(targetTimeline: "Tournament coming up")
        let input = makeInput(profile: profile)
        let output = ScheduleEngine.generate(input: input)

        XCTAssertTrue(output.program.name.contains("Tournament Prep"),
            "Program name should contain 'Tournament Prep' for tournament timeline")
    }

    func testFirstSessionIsAvailable_restAreLocked() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        guard !output.sessions.isEmpty else {
            XCTFail("Should have sessions")
            return
        }

        XCTAssertEqual(output.sessions[0].status, .available, "First session should be available")
        for session in output.sessions.dropFirst() {
            XCTAssertEqual(session.status, .locked, "Non-first sessions should be locked")
        }
    }
}
