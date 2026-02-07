import Foundation

protocol ProgressCheckerRepository {
    func fetchForSkill(_ skillId: UUID) async throws -> [ProgressChecker]
    func save(_ checker: ProgressChecker) async throws
    func toggleCompletion(_ id: UUID) async throws
    func delete(_ id: UUID) async throws
}
