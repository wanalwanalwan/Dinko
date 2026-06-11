import CoreData

extension FocusHistoryEntity {
    func toDomain() -> FocusHistoryEntry {
        FocusHistoryEntry(
            id: id ?? UUID(),
            skillId: skillId ?? UUID(),
            pillar: SkillPillar(rawValue: pillar ?? "consistency") ?? .consistency,
            date: date ?? Date(),
            sessionType: SessionType(rawValue: sessionType ?? "learn") ?? .learn,
            wasCompleted: wasCompleted,
            wasSwapped: wasSwapped,
            checkInResponse: checkInResponse
        )
    }

    func update(from entry: FocusHistoryEntry) {
        id = entry.id
        skillId = entry.skillId
        pillar = entry.pillar.rawValue
        date = entry.date
        sessionType = entry.sessionType.rawValue
        wasCompleted = entry.wasCompleted
        wasSwapped = entry.wasSwapped
        checkInResponse = entry.checkInResponse
    }
}
