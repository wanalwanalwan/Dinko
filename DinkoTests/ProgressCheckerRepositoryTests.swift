import XCTest
@testable import Dinko

final class ProgressCheckerRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var skillRepository: SkillRepositoryImpl!
    var checkerRepository: ProgressCheckerRepositoryImpl!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        skillRepository = SkillRepositoryImpl(persistence: persistence)
        checkerRepository = ProgressCheckerRepositoryImpl(persistence: persistence)
    }

    override func tearDown() {
        checkerRepository = nil
        skillRepository = nil
        persistence = nil
        super.tearDown()
    }

    func testSaveAndFetchForSkill() async throws {
        let skill = Skill(name: "Serve")
        try await skillRepository.save(skill)

        let checker = ProgressChecker(skillId: skill.id, name: "Deep serve")
        try await checkerRepository.save(checker)

        let checkers = try await checkerRepository.fetchForSkill(skill.id)
        XCTAssertEqual(checkers.count, 1)
        XCTAssertEqual(checkers.first?.name, "Deep serve")
        XCTAssertFalse(checkers.first?.isCompleted ?? true)
    }

    func testToggleCompletion() async throws {
        let skill = Skill(name: "Serve")
        try await skillRepository.save(skill)

        let checker = ProgressChecker(skillId: skill.id, name: "Spin serve")
        try await checkerRepository.save(checker)

        try await checkerRepository.toggleCompletion(checker.id)

        let checkers = try await checkerRepository.fetchForSkill(skill.id)
        XCTAssertTrue(checkers.first?.isCompleted ?? false)
        XCTAssertNotNil(checkers.first?.completedDate)
    }

    func testToggleCompletionTwice() async throws {
        let skill = Skill(name: "Serve")
        try await skillRepository.save(skill)

        let checker = ProgressChecker(skillId: skill.id, name: "Power serve")
        try await checkerRepository.save(checker)

        try await checkerRepository.toggleCompletion(checker.id)
        try await checkerRepository.toggleCompletion(checker.id)

        let checkers = try await checkerRepository.fetchForSkill(skill.id)
        XCTAssertFalse(checkers.first?.isCompleted ?? true)
        XCTAssertNil(checkers.first?.completedDate)
    }

    func testFetchBySkillReturnsOnlyRelevant() async throws {
        let skill1 = Skill(name: "Serve")
        let skill2 = Skill(name: "Dink")
        try await skillRepository.save(skill1)
        try await skillRepository.save(skill2)

        let checker1 = ProgressChecker(skillId: skill1.id, name: "Deep serve")
        let checker2 = ProgressChecker(skillId: skill2.id, name: "Cross-court dink")
        try await checkerRepository.save(checker1)
        try await checkerRepository.save(checker2)

        let serveCheckers = try await checkerRepository.fetchForSkill(skill1.id)
        XCTAssertEqual(serveCheckers.count, 1)
        XCTAssertEqual(serveCheckers.first?.name, "Deep serve")
    }

    func testDelete() async throws {
        let skill = Skill(name: "Serve")
        try await skillRepository.save(skill)

        let checker = ProgressChecker(skillId: skill.id, name: "To delete")
        try await checkerRepository.save(checker)

        try await checkerRepository.delete(checker.id)

        let checkers = try await checkerRepository.fetchForSkill(skill.id)
        XCTAssertEqual(checkers.count, 0)
    }
}
