import CoreData

final class SkillRatingRepositoryImpl: SkillRatingRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchForSkill(_ skillId: UUID) async throws -> [SkillRating] {
        let context = persistence.container.viewContext
        return try await context.perform {
            let request = SkillRatingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillRatingEntity.date, ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchLatest(_ skillId: UUID) async throws -> SkillRating? {
        let context = persistence.container.viewContext
        return try await context.perform {
            let request = SkillRatingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillRatingEntity.date, ascending: false)]
            request.fetchLimit = 1
            let entity = try context.fetch(request).first
            return entity?.toDomain()
        }
    }

    func save(_ rating: SkillRating) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SkillRatingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", rating.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? SkillRatingEntity(context: context)
            entity.update(from: rating)

            let skillRequest = SkillEntity.fetchRequest()
            skillRequest.predicate = NSPredicate(format: "id == %@", rating.skillId as CVarArg)
            skillRequest.fetchLimit = 1
            entity.skill = try context.fetch(skillRequest).first

            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SkillRatingEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
