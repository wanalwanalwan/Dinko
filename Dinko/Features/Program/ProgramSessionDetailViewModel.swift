import Foundation

@MainActor
@Observable
final class ProgramSessionDetailViewModel {
    private(set) var session: ProgramSession
    private(set) var drills: [ProgramDrill] = []
    private(set) var isLoading = false
    private(set) var showCelebration = false
    var errorMessage: String?

    private let programRepository: ProgramRepository

    init(session: ProgramSession, programRepository: ProgramRepository) {
        self.session = session
        self.programRepository = programRepository
    }

    // MARK: - Computed

    var allDrillsComplete: Bool {
        !drills.isEmpty && drills.allSatisfy { $0.status != .pending }
    }

    var completedDrillCount: Int {
        drills.filter { $0.status == .completed }.count
    }

    var totalMinutesRemaining: Int {
        drills.filter { $0.status == .pending }.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Actions

    func loadDrills() async {
        isLoading = true
        defer { isLoading = false }

        do {
            drills = try await programRepository.fetchDrills(for: session.id)
            errorMessage = nil
        } catch {
            errorMessage = "Failed to load drills."
        }
    }

    func completeDrill(_ id: UUID) async {
        do {
            try await programRepository.completeDrill(id)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].status = .completed
                drills[index].completedReps = drills[index].targetReps
            }

            // Track total drills completed
            let total = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")
            UserDefaults.standard.set(total + 1, forKey: "pkkl_total_drills_completed")
        } catch {
            errorMessage = "Failed to complete drill."
        }
    }

    func incrementRep(_ id: UUID) async {
        do {
            try await programRepository.incrementDrillReps(id)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].completedReps += 1
                if drills[index].completedReps >= drills[index].targetReps {
                    drills[index].status = .completed

                    let total = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")
                    UserDefaults.standard.set(total + 1, forKey: "pkkl_total_drills_completed")
                }
            }
        } catch {
            errorMessage = "Failed to update reps."
        }
    }

    func skipDrill(_ id: UUID) async {
        do {
            try await programRepository.updateDrillStatus(id, status: .skipped)
            if let index = drills.firstIndex(where: { $0.id == id }) {
                drills[index].status = .skipped
            }
        } catch {
            errorMessage = "Failed to skip drill."
        }
    }

    func completeSession() async {
        do {
            try await programRepository.completeSession(session.id)
            session.status = .completed
            session.completedDate = Date()
            showCelebration = true
        } catch {
            errorMessage = "Failed to complete session."
        }
    }
}
