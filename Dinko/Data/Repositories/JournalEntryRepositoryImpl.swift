import CoreData

final class JournalEntryRepositoryImpl: JournalEntryRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [JournalEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = JournalEntryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \JournalEntryEntity.date, ascending: false)]
            request.fetchLimit = 500
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func save(_ entry: JournalEntry) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = JournalEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? JournalEntryEntity(context: context)
            entity.update(from: entry)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = JournalEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
