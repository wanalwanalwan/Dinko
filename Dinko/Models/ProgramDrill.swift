import Foundation

struct ProgramDrill: Identifiable, Hashable {
    let id: UUID
    var programSessionId: UUID
    var name: String
    var drillDescription: String
    var durationMinutes: Int
    var targetReps: Int
    var completedReps: Int
    var equipment: String
    var playerCount: Int
    var displayOrder: Int
    var status: DrillStatus
    var createdDate: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        programSessionId: UUID,
        name: String,
        drillDescription: String = "",
        durationMinutes: Int = 10,
        targetReps: Int = 1,
        completedReps: Int = 0,
        equipment: String = "",
        playerCount: Int = 1,
        displayOrder: Int = 0,
        status: DrillStatus = .pending,
        createdDate: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.programSessionId = programSessionId
        self.name = name
        self.drillDescription = drillDescription
        self.durationMinutes = durationMinutes
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.equipment = equipment
        self.playerCount = playerCount
        self.displayOrder = displayOrder
        self.status = status
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }

    var isRepComplete: Bool { completedReps >= targetReps }
    var repsRemaining: Int { max(0, targetReps - completedReps) }
}
