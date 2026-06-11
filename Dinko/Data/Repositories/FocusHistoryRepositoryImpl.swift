import CoreData

final class FocusHistoryRepositoryImpl: FocusHistoryRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [FocusHistoryEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = FocusHistoryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusHistoryEntity.date, ascending: false)]
            request.fetchLimit = 1000
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchRecent(limit: Int) async throws -> [FocusHistoryEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = FocusHistoryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusHistoryEntity.date, ascending: false)]
            request.fetchLimit = limit
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func save(_ entry: FocusHistoryEntry) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = FocusHistoryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? FocusHistoryEntity(context: context)
            entity.update(from: entry)
            try context.save()
        }
    }
}
