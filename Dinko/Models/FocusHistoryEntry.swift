import Foundation

/// Tracks daily recommendations and whether they were completed.
struct FocusHistoryEntry: Identifiable, Hashable {
    let id: UUID
    let skillId: UUID
    let pillar: SkillPillar
    let date: Date
    let sessionType: SessionType
    var wasCompleted: Bool
    var wasSwapped: Bool
    var checkInResponse: String?

    init(
        id: UUID = UUID(),
        skillId: UUID,
        pillar: SkillPillar,
        date: Date = Date(),
        sessionType: SessionType,
        wasCompleted: Bool = false,
        wasSwapped: Bool = false,
        checkInResponse: String? = nil
    ) {
        self.id = id
        self.skillId = skillId
        self.pillar = pillar
        self.date = date
        self.sessionType = sessionType
        self.wasCompleted = wasCompleted
        self.wasSwapped = wasSwapped
        self.checkInResponse = checkInResponse
    }
}
