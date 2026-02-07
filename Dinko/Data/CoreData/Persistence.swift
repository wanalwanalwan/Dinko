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
        skill.iconName = "figure.pickleball"
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
            fatalError("Preview PersistenceController save error: \(error)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Dinko")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}
