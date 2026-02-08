import CoreData

struct PersistenceController {
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
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        var storeError: NSError?
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                storeError = error
                // Fall back to in-memory store so the app doesn't crash
                let description = NSPersistentStoreDescription()
                description.type = NSInMemoryStoreType
                container.persistentStoreDescriptions = [description]
                container.loadPersistentStores { _, fallbackError in
                    if fallbackError != nil {
                        // In-memory fallback also failed; app will show error state
                    }
                }
            }
        }
        loadError = storeError
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
