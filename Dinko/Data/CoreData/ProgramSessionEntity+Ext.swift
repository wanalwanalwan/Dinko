import CoreData

extension ProgramSessionEntity {
    func toDomain() -> ProgramSession {
        let dayOfWeek: Int? = scheduledDayOfWeek == -1 ? nil : Int(scheduledDayOfWeek)
        return ProgramSession(
            id: id ?? UUID(),
            programId: programId ?? UUID(),
            weekNumber: Int(weekNumber),
            sessionNumber: Int(sessionNumber),
            title: title ?? "",
            focus: focus ?? "",
            estimatedMinutes: Int(estimatedMinutes),
            scheduledDayOfWeek: dayOfWeek,
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
        scheduledDayOfWeek = Int16(session.scheduledDayOfWeek ?? -1)
        status = session.status.rawValue
        completedDate = session.completedDate
        createdDate = session.createdDate
        updatedAt = session.updatedAt
    }
}
