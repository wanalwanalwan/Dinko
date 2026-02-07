import XCTest
@testable import Dinko

final class SkillRepositoryTests: XCTestCase {
    var persistence: PersistenceController!
    var repository: SkillRepositoryImpl!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        repository = SkillRepositoryImpl(persistence: persistence)
    }

    override func tearDown() {
        repository = nil
        persistence = nil
        super.tearDown()
    }

    func testSaveAndFetchAll() async throws {
        let skill = Skill(name: "Serve", category: .offense)
        try await repository.save(skill)

        let skills = try await repository.fetchAll()
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "Serve")
        XCTAssertEqual(skills.first?.category, .offense)
    }

    func testFetchById() async throws {
        let skill = Skill(name: "Dink", category: .strategy)
        try await repository.save(skill)

        let fetched = try await repository.fetchById(skill.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Dink")
    }

    func testFetchByIdReturnsNilForUnknown() async throws {
        let fetched = try await repository.fetchById(UUID())
        XCTAssertNil(fetched)
    }

    func testDelete() async throws {
        let skill = Skill(name: "Volley", category: .offense)
        try await repository.save(skill)

        try await repository.delete(skill.id)

        let skills = try await repository.fetchAll()
        XCTAssertEqual(skills.count, 0)
    }

    func testFetchActiveFiltersArchived() async throws {
        let active = Skill(name: "Active Skill", status: .active)
        let archived = Skill(name: "Archived Skill", status: .archived, archivedDate: Date())
        try await repository.save(active)
        try await repository.save(archived)

        let activeSkills = try await repository.fetchActive()
        XCTAssertEqual(activeSkills.count, 1)
        XCTAssertEqual(activeSkills.first?.name, "Active Skill")
    }

    func testArchive() async throws {
        let skill = Skill(name: "To Archive", status: .active)
        try await repository.save(skill)

        try await repository.archive(skill.id)

        let activeSkills = try await repository.fetchActive()
        XCTAssertEqual(activeSkills.count, 0)

        let allSkills = try await repository.fetchAll()
        XCTAssertEqual(allSkills.count, 1)
        XCTAssertEqual(allSkills.first?.status, .archived)
        XCTAssertNotNil(allSkills.first?.archivedDate)
    }

    func testReorder() async throws {
        let skill1 = Skill(name: "First", displayOrder: 0)
        let skill2 = Skill(name: "Second", displayOrder: 1)
        let skill3 = Skill(name: "Third", displayOrder: 2)
        try await repository.save(skill1)
        try await repository.save(skill2)
        try await repository.save(skill3)

        try await repository.reorder([skill3, skill1, skill2])

        let skills = try await repository.fetchAll()
        XCTAssertEqual(skills[0].name, "Third")
        XCTAssertEqual(skills[1].name, "First")
        XCTAssertEqual(skills[2].name, "Second")
    }

    func testUpdateExistingSkill() async throws {
        var skill = Skill(name: "Original Name")
        try await repository.save(skill)

        skill.name = "Updated Name"
        skill.category = .defense
        try await repository.save(skill)

        let skills = try await repository.fetchAll()
        XCTAssertEqual(skills.count, 1)
        XCTAssertEqual(skills.first?.name, "Updated Name")
        XCTAssertEqual(skills.first?.category, .defense)
    }
}
