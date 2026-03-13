import CoreData

extension DrillEntity {
    func toDomain() -> Drill {
        Drill(
            id: id ?? UUID(),
            skillId: skillId ?? UUID(),
            name: name ?? "",
            drillDescription: drillDescription ?? "",
            targetSubskill: targetSubskill,
            durationMinutes: Int(durationMinutes),
            playerCount: Int(playerCount),
            equipment: equipment ?? "",
            reason: reason ?? "",
            priority: priority ?? "medium",
            status: DrillStatus(rawValue: status ?? "pending") ?? .pending,
            targetReps: Int(targetReps),
            completedReps: Int(completedReps),
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from drill: Drill) {
        id = drill.id
        skillId = drill.skillId
        name = drill.name
        drillDescription = drill.drillDescription
        targetSubskill = drill.targetSubskill
        durationMinutes = Int16(drill.durationMinutes)
        playerCount = Int16(drill.playerCount)
        equipment = drill.equipment
        reason = drill.reason
        priority = drill.priority
        status = drill.status.rawValue
        targetReps = Int16(drill.targetReps)
        completedReps = Int16(drill.completedReps)
        createdDate = drill.createdDate
        updatedAt = drill.updatedAt
    }
}
