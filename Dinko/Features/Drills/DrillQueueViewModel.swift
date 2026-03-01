import Foundation

@MainActor
@Observable
final class DrillQueueViewModel {
    private(set) var pendingDrills: [Drill] = []
    private(set) var completedDrills: [Drill] = []
    private(set) var skillNames: [UUID: String] = [:]
    var errorMessage: String?

    var totalEstimatedMinutes: Int {
        pendingDrills.reduce(0) { $0 + $1.durationMinutes }
    }

    private let drillRepository: DrillRepository
    private let skillRepository: SkillRepository

    init(drillRepository: DrillRepository, skillRepository: SkillRepository) {
        self.drillRepository = drillRepository
        self.skillRepository = skillRepository
    }

    func loadDrills() async {
        do {
            let allDrills = try await drillRepository.fetchAll()

            // Sort pending: high > medium > low, then oldest first
            pendingDrills = allDrills
                .filter { $0.status == .pending }
                .sorted { lhs, rhs in
                    let lhsPriority = priorityOrder(lhs.priority)
                    let rhsPriority = priorityOrder(rhs.priority)
                    if lhsPriority != rhsPriority {
                        return lhsPriority < rhsPriority
                    }
                    return lhs.createdDate < rhs.createdDate
                }

            // Completed/skipped, most recent first, capped at 20
            completedDrills = allDrills
                .filter { $0.status == .completed || $0.status == .skipped }
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(20)
                .map { $0 }

            // Build skill name map
            let skills = try await skillRepository.fetchAll()
            skillNames = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0.name) })

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markDone(_ drillId: UUID) async {
        do {
            try await drillRepository.updateStatus(drillId, status: .completed)
            await loadDrills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skip(_ drillId: UUID) async {
        do {
            try await drillRepository.updateStatus(drillId, status: .skipped)
            await loadDrills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func priorityOrder(_ priority: String) -> Int {
        switch priority {
        case "high": 0
        case "medium": 1
        default: 2
        }
    }
}
