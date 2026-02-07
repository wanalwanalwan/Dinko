import Foundation

protocol SkillRatingRepository {
    func fetchForSkill(_ skillId: UUID) async throws -> [SkillRating]
    func fetchLatest(_ skillId: UUID) async throws -> SkillRating?
    func save(_ rating: SkillRating) async throws
    func delete(_ id: UUID) async throws
}
