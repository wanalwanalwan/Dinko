import Foundation

protocol FocusHistoryRepository {
    func fetchAll() async throws -> [FocusHistoryEntry]
    func fetchRecent(limit: Int) async throws -> [FocusHistoryEntry]
    func save(_ entry: FocusHistoryEntry) async throws
}
