import Foundation

enum SkillPillar: String, CaseIterable, Codable, Identifiable {
    case consistency
    case transition
    case attack
    case movement
    case strategy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .consistency: return "Consistency"
        case .transition: return "Transition"
        case .attack: return "Attack"
        case .movement: return "Movement"
        case .strategy: return "Strategy"
        }
    }

    var iconName: String {
        switch self {
        case .consistency: return "\u{1F3AF}" // target emoji
        case .transition: return "\u{1F504}" // arrows emoji
        case .attack: return "\u{26A1}"      // lightning emoji
        case .movement: return "\u{1F45F}"   // sneaker emoji
        case .strategy: return "\u{265F}\u{FE0F}" // chess pawn emoji
        }
    }

    var sfSymbol: String {
        switch self {
        case .consistency: return "target"
        case .transition: return "arrow.triangle.2.circlepath"
        case .attack: return "bolt.fill"
        case .movement: return "figure.run"
        case .strategy: return "brain.head.profile"
        }
    }

    /// Map legacy SkillCategory to SkillPillar
    static func from(category: SkillCategory) -> SkillPillar {
        switch category {
        case .dinking: return .consistency
        case .serves: return .consistency
        case .drops: return .transition
        case .defense: return .consistency
        case .drives: return .attack
        case .offense: return .attack
        case .strategy: return .strategy
        }
    }
}
