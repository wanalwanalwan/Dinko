import CoreData

extension ConfidenceEntryEntity {
    func toDomain() -> ConfidenceEntry {
        ConfidenceEntry(
            id: id ?? UUID(),
            skillId: skillId ?? UUID(),
            confidence: Int(confidence),
            source: ConfidenceSource(rawValue: source ?? "manual") ?? .manual,
            date: date ?? Date()
        )
    }

    func update(from entry: ConfidenceEntry) {
        id = entry.id
        skillId = entry.skillId
        confidence = Int16(entry.confidence)
        source = entry.source.rawValue
        date = entry.date
    }
}
