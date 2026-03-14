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
        case .dinking: return "🥒"
        case .drops: return "⬇️"
        case .drives: return "🚀"
        case .defense: return "🛡️"
        case .offense: return "🔥"
        case .strategy: return "♟️"
        case .serves: return "🎯"
        }
    }

    var sfSymbol: String {
        switch self {
        case .dinking: return "hand.raised.fill"
        case .drops: return "arrow.down.to.line"
        case .drives: return "bolt.horizontal.fill"
        case .defense: return "shield.lefthalf.filled"
        case .offense: return "flame.fill"
        case .strategy: return "brain.head.profile"
        case .serves: return "arrow.up.forward"
        }
    }
}
