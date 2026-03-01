import Foundation

protocol DrillRepository {
    func fetchAll() async throws -> [Drill]
    func fetchForSkill(_ skillId: UUID) async throws -> [Drill]
    func save(_ drill: Drill) async throws
    func delete(_ id: UUID) async throws
    func updateStatus(_ id: UUID, status: DrillStatus) async throws
}
