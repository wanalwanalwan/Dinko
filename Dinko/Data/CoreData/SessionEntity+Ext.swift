import CoreData

extension SessionEntity {
    func toDomain() -> Session {
        Session(
            id: id ?? UUID(),
            date: date ?? Date(),
            duration: Int(duration),
            notes: notes,
            sessionType: SessionType(rawValue: sessionType ?? "game") ?? .game,
            skillIds: skillIds ?? "",
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from session: Session) {
        id = session.id
        date = session.date
        duration = Int16(session.duration)
        notes = session.notes
        sessionType = session.sessionType.rawValue
        skillIds = session.skillIds
        updatedAt = session.updatedAt
    }
}
