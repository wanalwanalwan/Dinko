import CoreData

extension ProgressCheckerEntity {
    func toDomain() -> ProgressChecker {
        ProgressChecker(
            id: id ?? UUID(),
            skillId: skillId ?? UUID(),
            name: name ?? "",
            isCompleted: isCompleted,
            completedDate: completedDate,
            displayOrder: Int(displayOrder),
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from checker: ProgressChecker) {
        id = checker.id
        skillId = checker.skillId
        name = checker.name
        isCompleted = checker.isCompleted
        completedDate = checker.completedDate
        displayOrder = Int16(checker.displayOrder)
        updatedAt = checker.updatedAt
    }
}
