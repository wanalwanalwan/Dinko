import Foundation

protocol SessionRepository {
    func fetchAll() async throws -> [Session]
    func fetchById(_ id: UUID) async throws -> Session?
    func save(_ session: Session) async throws
    func delete(_ id: UUID) async throws
}
