import CoreData

final class SkillRepositoryImpl: SkillRepository {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    func fetchAll() async throws -> [Skill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillEntity.displayOrder, ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchActive() async throws -> [Skill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "status == %@", "active")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillEntity.displayOrder, ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchArchived() async throws -> [Skill] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "status == %@", "archived")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \SkillEntity.archivedDate, ascending: false)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchById(_ id: UUID) async throws -> Skill? {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first
            return entity?.toDomain()
        }
    }

    func save(_ skill: Skill) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", skill.id as CVarArg)
            request.fetchLimit = 1
            let entity = try context.fetch(request).first ?? SkillEntity(context: context)
            entity.update(from: skill)
            try context.save()
        }
    }

    func delete(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                try context.save()
            }
        }
    }

    func archive(_ id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let request = SkillEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try context.fetch(request).first {
                entity.status = SkillStatus.archived.rawValue
                entity.archivedDate = Date()
                entity.updatedAt = Date()
                try context.save()
            }
        }
    }

    func reorder(_ skills: [Skill]) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            for (index, skill) in skills.enumerated() {
                let request = SkillEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", skill.id as CVarArg)
                request.fetchLimit = 1
                if let entity = try context.fetch(request).first {
                    entity.displayOrder = Int16(index)
                    entity.updatedAt = Date()
                }
            }
            try context.save()
        }
    }
}
