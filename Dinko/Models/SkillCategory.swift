import Foundation

enum SkillCategory: String, CaseIterable, Codable, Identifiable {
    case dinking
    case drops
    case drives
    case defense
    case offense
    case strategy
    case serves

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var iconName: String {
        switch self {
        case .dinking: return "figure.pickleball"
        case .drops: return "arrow.down.right.circle.fill"
        case .drives: return "bolt.fill"
        case .defense: return "shield.fill"
        case .offense: return "flame.fill"
        case .strategy: return "brain.head.profile"
        case .serves: return "arrow.up.forward"
        }
    }
}
