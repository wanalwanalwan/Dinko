import Foundation

protocol JournalEntryRepository {
    func fetchAll() async throws -> [JournalEntry]
    func save(_ entry: JournalEntry) async throws
    func delete(_ id: UUID) async throws
}
