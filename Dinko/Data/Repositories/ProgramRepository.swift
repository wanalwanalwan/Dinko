import Foundation

protocol ProgramRepository {
    func fetchAll() async throws -> [Program]
    func fetchActive() async throws -> Program?
    func save(_ program: Program) async throws
    func delete(_ id: UUID) async throws
    func updateStatus(_ id: UUID, status: ProgramStatus) async throws

    func fetchSessions(for programId: UUID) async throws -> [ProgramSession]
    func completeSession(_ id: UUID) async throws

    func fetchDrills(for sessionId: UUID) async throws -> [ProgramDrill]
    func completeDrill(_ id: UUID) async throws
    func updateDrillStatus(_ id: UUID, status: DrillStatus) async throws
    func incrementDrillReps(_ id: UUID) async throws

    func saveFullProgram(
        _ program: Program,
        sessions: [ProgramSession],
        drills: [UUID: [ProgramDrill]]
    ) async throws

    func saveDrillsForSession(_ sessionId: UUID, drills: [ProgramDrill]) async throws
    func updateSessionFocus(_ sessionId: UUID, focus: String) async throws
}
