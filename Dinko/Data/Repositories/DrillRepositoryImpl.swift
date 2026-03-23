import CoreData

final class DrillRepositoryImpl: DrillRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [Drill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \DrillEntity.createdDate, ascending: false)]
            request.fetchLimit = 500
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchForSkill(_ skillId: UUID) async throws -> [Drill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \DrillEntity.createdDate, ascending: false)]
            request.fetchLimit = 100
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func save(_ drill: Drill) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", drill.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? DrillEntity(context: context)
            entity.update(from: drill)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    func updateStatus(_ id: UUID, status: DrillStatus) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.status = status.rawValue
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    func incrementReps(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = DrillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.completedReps += 1
                if entity.completedReps >= entity.targetReps {
                    entity.status = DrillStatus.completed.rawValue
                }
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }
}
