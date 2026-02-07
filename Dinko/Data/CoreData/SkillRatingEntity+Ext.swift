import CoreData

extension SkillRatingEntity {
    func toDomain() -> SkillRating {
        SkillRating(
            id: id ?? UUID(),
            skillId: skillId ?? UUID(),
            rating: Int(rating),
            date: date ?? Date(),
            notes: notes,
            updatedAt: updatedAt ?? Date()
        )
    }

    func update(from skillRating: SkillRating) {
        id = skillRating.id
        skillId = skillRating.skillId
        rating = Int16(skillRating.rating)
        date = skillRating.date
        notes = skillRating.notes
        updatedAt = skillRating.updatedAt
    }
}
