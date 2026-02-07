import Foundation

enum SkillCategory: String, CaseIterable, Codable, Identifiable {
    case offense
    case defense
    case strategy
    case movement
    case general

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}
