import Foundation

enum ConfidenceSource: String, Codable {
    case onboarding
    case checkIn
    case manual
    case periodic

    var displayLabel: String {
        switch self {
        case .onboarding: return "Onboarding"
        case .checkIn: return "Check-in"
        case .manual: return "Manual update"
        case .periodic: return "Periodic review"
        }
    }
}

struct ConfidenceEntry: Identifiable, Hashable {
    let id: UUID
    let skillId: UUID
    let confidence: Int // 1-10
    let source: ConfidenceSource
    let date: Date

    init(
        id: UUID = UUID(),
        skillId: UUID,
        confidence: Int,
        source: ConfidenceSource = .manual,
        date: Date = Date()
    ) {
        self.id = id
        self.skillId = skillId
        self.confidence = min(max(confidence, 1), 10)
        self.source = source
        self.date = date
    }
}
