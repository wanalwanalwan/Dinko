import CoreData

final class ProgressCheckerRepositoryImpl: ProgressCheckerRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchForSkill(_ skillId: UUID) async throws -> [ProgressChecker] {
        let context = persistence.container.viewContext
        return try await context.perform {
            let request = ProgressCheckerEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ProgressCheckerEntity.displayOrder, ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func save(_ checker: ProgressChecker) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgressCheckerEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", checker.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? ProgressCheckerEntity(context: context)
            entity.update(from: checker)

            let skillRequest = SkillEntity.fetchRequest()
            skillRequest.predicate = NSPredicate(format: "id == %@", checker.skillId as CVarArg)
            skillRequest.fetchLimit = 1
            entity.skill = try context.fetch(skillRequest).first

            try context.save()
        }
    }

    func toggleCompletion(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgressCheckerEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.isCompleted.toggle()
                entity.completedDate = entity.isCompleted ? Date() : nil
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ProgressCheckerEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
