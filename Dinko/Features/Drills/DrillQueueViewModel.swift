import Foundation

@MainActor
@Observable
final class DrillQueueViewModel {
    private(set) var pendingDrills: [Drill] = []
    private(set) var completedDrills: [Drill] = []
    private(set) var skillNames: [UUID: String] = [:]
    var errorMessage: String?
    var showCelebration = false

    var totalDrillsCompleted: Int {
        get { UserDefaults.standard.integer(forKey: "dinko_total_drills_completed") }
        set { UserDefaults.standard.set(newValue, forKey: "dinko_total_drills_completed") }
    }

    var totalEstimatedMinutes: Int {
        pendingDrills.reduce(0) { $0 + $1.durationMinutes }
    }

    var focusSkillName: String? {
        let skillCounts = pendingDrills.reduce(into: [UUID: Int]()) { counts, drill in
            counts[drill.skillId, default: 0] += 1
        }
        guard let topSkillId = skillCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        return skillNames[topSkillId]
    }

    var sessionProgress: Double {
        let total = completedTodayCount + pendingDrills.count
        guard total > 0 else { return 0 }
        return Double(completedTodayCount) / Double(total)
    }

    var completedTodayCount: Int {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return completedDrills.filter { $0.updatedAt >= startOfDay }.count
    }

    var mascotTip: String {
        let tips = [
            "Focus on form over power today!",
            "Soft hands win points. Keep it loose!",
            "Reset to ready position after every shot.",
            "Watch the ball all the way to your paddle.",
            "Patience at the kitchen line pays off!",
            "Practice your third shot drop today.",
            "Stay low and balanced on dinks.",
            "Move your feet, not just your arm!",
            "Aim for consistency, not winners.",
            "Deep returns give you time to advance."
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return tips[dayOfYear % tips.count]
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
            totalDrillsCompleted += 1
            showCelebration = true
            await loadDrills()
            try? await Task.sleep(for: .seconds(2))
            showCelebration = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func doRep(_ drillId: UUID) async {
        do {
            try await drillRepository.incrementReps(drillId)
            await loadDrills()

            // Check if the drill just completed (no longer in pending)
            let justCompleted = !pendingDrills.contains(where: { $0.id == drillId })
            if justCompleted {
                totalDrillsCompleted += 1
                showCelebration = true
                try? await Task.sleep(for: .seconds(2))
                showCelebration = false
            }
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
