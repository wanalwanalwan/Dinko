import CoreData

extension ProgramSessionEntity {
    func toDomain() -> ProgramSession {
        ProgramSession(
            id: id ?? UUID(),
            programId: programId ?? UUID(),
            weekNumber: Int(weekNumber),
            sessionNumber: Int(sessionNumber),
            title: title ?? "",
            focus: focus ?? "",
            estimatedMinutes: Int(estimatedMinutes),
            status: ProgramSessionStatus(rawValue: status ?? "locked") ?? .locked,
            completedDate: completedDate,
            createdDate: createdDate ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from session: ProgramSession) {
        id = session.id
        programId = session.programId
        weekNumber = Int16(session.weekNumber)
        sessionNumber = Int16(session.sessionNumber)
        title = session.title
        focus = session.focus
        estimatedMinutes = Int16(session.estimatedMinutes)
        status = session.status.rawValue
        completedDate = session.completedDate
        createdDate = session.createdDate
        updatedAt = session.updatedAt
    }
}
