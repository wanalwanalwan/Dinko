import CoreData

final class ConfidenceEntryRepositoryImpl: ConfidenceEntryRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchForSkill(_ skillId: UUID) async throws -> [ConfidenceEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ConfidenceEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ConfidenceEntryEntity.date, ascending: true)]
            request.fetchLimit = 500
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchLatest(_ skillId: UUID) async throws -> ConfidenceEntry? {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ConfidenceEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "skillId == %@", skillId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ConfidenceEntryEntity.date, ascending: false)]
            request.fetchLimit = 1
            let entity = try context.fetch(request).first
            return entity?.toDomain()
        }
    }

    func fetchAll() async throws -> [ConfidenceEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = ConfidenceEntryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ConfidenceEntryEntity.date, ascending: false)]
            request.fetchLimit = 1000
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchStale(olderThan date: Date) async throws -> [ConfidenceEntry] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            // For each skill, find the latest entry and check if it's older than the threshold.
            // We fetch all entries grouped by skillId, take the latest per skill.
            let request = ConfidenceEntryEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \ConfidenceEntryEntity.date, ascending: false)]
            request.fetchLimit = 5000
            let entities = try context.fetch(request)

            // Group by skillId, take latest per skill, filter stale
            var latestBySkill: [UUID: ConfidenceEntryEntity] = [:]
            for entity in entities {
                guard let skillId = entity.skillId else { continue }
                if latestBySkill[skillId] == nil {
                    latestBySkill[skillId] = entity
                }
            }

            return latestBySkill.values
                .filter { ($0.date ?? Date()) < date }
                .map { $0.toDomain() }
        }
    }

    func save(_ entry: ConfidenceEntry) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ConfidenceEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", entry.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? ConfidenceEntryEntity(context: context)
            entity.update(from: entry)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = ConfidenceEntryEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }
}
