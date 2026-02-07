import Foundation

protocol SkillRepository {
    func fetchAll() async throws -> [Skill]
    func fetchActive() async throws -> [Skill]
    func fetchById(_ id: UUID) async throws -> Skill?
    func save(_ skill: Skill) async throws
    func delete(_ id: UUID) async throws
    func archive(_ id: UUID) async throws
    func reorder(_ skills: [Skill]) async throws
}
