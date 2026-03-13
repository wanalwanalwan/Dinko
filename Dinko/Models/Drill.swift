import SwiftUI

struct Drill: Identifiable, Hashable {
    let id: UUID
    var skillId: UUID
    var name: String
    var drillDescription: String
    var targetSubskill: String?
    var durationMinutes: Int
    var playerCount: Int
    var equipment: String
    var reason: String
    var priority: String
    var status: DrillStatus
    var targetReps: Int
    var completedReps: Int
    var createdDate: Date
    var updatedAt: Date

    var isRepComplete: Bool { completedReps >= targetReps }
    var repsRemaining: Int { max(0, targetReps - completedReps) }

    init(
        id: UUID = UUID(),
        skillId: UUID,
        name: String,
        drillDescription: String = "",
        targetSubskill: String? = nil,
        durationMinutes: Int = 10,
        playerCount: Int = 1,
        equipment: String = "",
        reason: String = "",
        priority: String = "medium",
        status: DrillStatus = .pending,
        targetReps: Int = 1,
        completedReps: Int = 0,
        createdDate: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.name = name
        self.drillDescription = drillDescription
        self.targetSubskill = targetSubskill
        self.durationMinutes = durationMinutes
        self.playerCount = playerCount
        self.equipment = equipment
        self.reason = reason
        self.priority = priority
        self.status = status
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.createdDate = createdDate
        self.updatedAt = updatedAt
    }
}

enum DrillStatus: String {
    case pending
    case completed
    case skipped
}

extension Drill {
    var priorityIcon: String {
        switch priority {
        case "high": "exclamationmark.circle.fill"
        case "medium": "circle.fill"
        default: "circle"
        }
    }

    var priorityColor: Color {
        switch priority {
        case "high": AppColors.coral
        case "medium": AppColors.teal
        default: AppColors.textSecondary
        }
    }
}
