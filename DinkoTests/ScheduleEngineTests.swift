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

    private func makeInput(
        profile: PlayerProfile? = nil,
        focusSkills: [FocusSkillEntry]? = nil
    ) -> ScheduleEngineInput {
        let p = profile ?? makeProfile()
        let fs = focusSkills ?? makeFocusSkills()

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
            sessionDurationMinutes: p.sessionDuration ?? 45
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
            XCTAssertEqual(s1.focus, s2.focus)
        }

        XCTAssertEqual(output1.program.name, output2.program.name)
        XCTAssertEqual(output1.program.programDescription, output2.program.programDescription)
    }

    func testSessionTypes_drillAndGameDaysGenerated() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        let drillSessions = output.sessions.filter { !$0.title.contains("Game Day") }
        let gameSessions = output.sessions.filter { $0.title.contains("Game Day") }

        XCTAssertFalse(drillSessions.isEmpty, "Should have drill day sessions")
        XCTAssertFalse(gameSessions.isEmpty, "Should have game day sessions")
    }

    func testGameDays_haveFocusText() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        let gameSessions = output.sessions.filter { $0.title.contains("Game Day") }
        for session in gameSessions {
            XCTAssertFalse(session.focus.isEmpty, "Game day should have focus text")
            XCTAssertTrue(session.focus.lowercased().contains("game play"),
                "Game day focus should mention game play, got: \(session.focus)")
        }
    }

    func testDrillDays_haveSkillNameInTitle() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        let drillSessions = output.sessions.filter { !$0.title.contains("Game Day") }
        for session in drillSessions {
            XCTAssertTrue(session.title.hasSuffix(" Drill Day"),
                "Drill session title should end with ' Drill Day', got: \(session.title)")
        }
    }

    func testSessionDuration_matchesConfigured() {
        let sessionDuration = 45
        let profile = makeProfile(sessionDuration: sessionDuration)
        let input = makeInput(profile: profile)
        let output = ScheduleEngine.generate(input: input)

        for session in output.sessions {
            XCTAssertEqual(session.estimatedMinutes, sessionDuration,
                "Session '\(session.title)' should match configured duration: \(session.estimatedMinutes) != \(sessionDuration)")
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

    func testSkillRotation_differentDrillDaysHaveDifferentSkills() {
        let input = makeInput()
        let output = ScheduleEngine.generate(input: input)

        // Check week 1 drill sessions have different titles (skill rotation)
        let week1DrillSessions = output.sessions.filter {
            $0.weekNumber == 1 && !$0.title.contains("Game Day")
        }

        if week1DrillSessions.count >= 2 {
            let titles = Set(week1DrillSessions.map(\.title))
            XCTAssertGreaterThan(titles.count, 1,
                "Different drill days in the same week should rotate skills")
        }
    }
}
