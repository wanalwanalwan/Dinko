import CoreData

extension ProgramEntity {
    func toDomain() -> Program {
        Program(
            id: id ?? UUID(),
            name: name ?? "",
            programDescription: programDescription ?? "",
            totalWeeks: Int(totalWeeks),
            sessionsPerWeek: Int(sessionsPerWeek),
            skillFocus: skillFocus ?? "",
            status: ProgramStatus(rawValue: status ?? "active") ?? .active,
            source: ProgramSource(rawValue: source ?? "ai") ?? .ai,
            isPremium: isPremium,
            currentWeek: Int(currentWeek),
            currentSession: Int(currentSession),
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from program: Program) {
        id = program.id
        name = program.name
        programDescription = program.programDescription
        totalWeeks = Int16(program.totalWeeks)
        sessionsPerWeek = Int16(program.sessionsPerWeek)
        skillFocus = program.skillFocus
        status = program.status.rawValue
        source = program.source.rawValue
        isPremium = program.isPremium
        currentWeek = Int16(program.currentWeek)
        currentSession = Int16(program.currentSession)
        createdDate = program.createdDate
        updatedAt = program.updatedAt
    }
}
