import Foundation

protocol ConfidenceEntryRepository {
    func fetchForSkill(_ skillId: UUID) async throws -> [ConfidenceEntry]
    func fetchLatest(_ skillId: UUID) async throws -> ConfidenceEntry?
    func fetchAll() async throws -> [ConfidenceEntry]
    func fetchStale(olderThan date: Date) async throws -> [ConfidenceEntry]
    func save(_ entry: ConfidenceEntry) async throws
    func delete(_ id: UUID) async throws
}
