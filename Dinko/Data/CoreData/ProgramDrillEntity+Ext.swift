import CoreData

extension ProgramDrillEntity {
    func toDomain() -> ProgramDrill {
        ProgramDrill(
            id: id ?? UUID(),
            programSessionId: programSessionId ?? UUID(),
            name: name ?? "",
            drillDescription: drillDescription ?? "",
            durationMinutes: Int(durationMinutes),
            targetReps: Int(targetReps),
            completedReps: Int(completedReps),
            equipment: equipment ?? "",
            playerCount: Int(playerCount),
            displayOrder: Int(displayOrder),
            status: DrillStatus(rawValue: status ?? "pending") ?? .pending,
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from drill: ProgramDrill) {
        id = drill.id
        programSessionId = drill.programSessionId
        name = drill.name
        drillDescription = drill.drillDescription
        durationMinutes = Int16(drill.durationMinutes)
        targetReps = Int16(drill.targetReps)
        completedReps = Int16(drill.completedReps)
        equipment = drill.equipment
        playerCount = Int16(drill.playerCount)
        displayOrder = Int16(drill.displayOrder)
        status = drill.status.rawValue
        createdDate = drill.createdDate
        updatedAt = drill.updatedAt
    }
}
