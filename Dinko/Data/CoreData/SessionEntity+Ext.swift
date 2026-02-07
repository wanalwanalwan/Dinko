import CoreData

extension SessionEntity {
    func toDomain() -> Session {
        Session(
            id: id ?? UUID(),
            date: date ?? Date(),
            duration: Int(duration),
            notes: notes,
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from session: Session) {
        id = session.id
        date = session.date
        duration = Int16(session.duration)
        notes = session.notes
        updatedAt = session.updatedAt
    }
}
