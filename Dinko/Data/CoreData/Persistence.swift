import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        let skill = SkillEntity(context: viewContext)
        skill.id = UUID()
        skill.name = "Serve"
        skill.category = "offense"
        skill.status = "active"
        skill.iconName = "🎯"
        skill.createdDate = Date()
        skill.updatedAt = Date()
        skill.displayOrder = 0

        let checker = ProgressCheckerEntity(context: viewContext)
        checker.id = UUID()
        checker.skillId = skill.id
        checker.name = "Consistent deep serve"
        checker.isCompleted = true
        checker.completedDate = Date()
        checker.updatedAt = Date()
        checker.skill = skill

        let rating = SkillRatingEntity(context: viewContext)
        rating.id = UUID()
        rating.skillId = skill.id
        rating.rating = 75
        rating.date = Date()
        rating.updatedAt = Date()
        rating.skill = skill

        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            fatalError("Preview PersistenceController save error: \(error)")
            #endif
        }

        return controller
    }()

    let container: NSPersistentContainer
    private(set) var loadError: NSError?

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Dinko")
        let persistentContainer = container
        if inMemory {
            persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable automatic lightweight migration for schema changes
        if let description = persistentContainer.persistentStoreDescriptions.first {
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }

        var storeError: NSError?
        persistentContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                storeError = error
                // Fall back to in-memory store so the app doesn't crash
                let description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
                persistentContainer.persistentStoreDescriptions = [description]
                persistentContainer.loadPersistentStores { _, fallbackError in
                    if fallbackError != nil {
                        // In-memory fallback also failed; app will show error state
                    }
                }
            }
        }
        loadError = storeError
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    /// Delete all data from every CoreData entity (used on sign-out to clear user data).
    func deleteAllData() async {
        let context = newBackgroundContext()
        let entityNames = [
            "SkillEntity",
            "ProgressCheckerEntity",
            "SkillRatingEntity",
            "DrillEntity",
            "JournalEntryEntity",
            "SessionEntity"
        ]
        await context.perform {
            for name in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                batchDelete.resultType = .resultTypeObjectIDs
                do {
                    let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                            into: [self.container.viewContext]
                        )
                    }
                } catch {
                    // Best-effort cleanup; log in debug builds
                    #if DEBUG
                    print("Failed to batch-delete \(name): \(error)")
                    #endif
                }
            }
        }
    }
}
