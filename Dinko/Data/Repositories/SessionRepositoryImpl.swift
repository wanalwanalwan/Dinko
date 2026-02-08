import CoreData

final class SessionRepositoryImpl: SessionRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [Session] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SessionEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SessionEntity.date, ascending: false)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchById(_ id: UUID) async throws -> Session? {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first
            return entity?.toDomain()
        }
    }

    func save(_ session: Session) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? SessionEntity(context: context)
            entity.update(from: session)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SessionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
