import SwiftUI

enum SkillTier: String, CaseIterable {
    case beginner
    case developing
    case solid
    case advanced
    case weapon

    init(rating: Int) {
        switch rating {
        case 0...20: self = .beginner
        case 21...40: self = .developing
        case 41...60: self = .solid
        case 61...80: self = .advanced
        default: self = .weapon
        }
    }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .developing: "Developing"
        case .solid: "Solid"
        case .advanced: "Advanced"
        case .weapon: "Weapon"
        }
    }

    var color: Color {
        switch self {
        case .beginner: AppColors.lockedGray
        case .developing: AppColors.tierBlue
        case .solid: AppColors.teal
        case .advanced: AppColors.tierGold
        case .weapon: AppColors.coral
        }
    }

    var sfSymbol: String {
        switch self {
        case .beginner: "leaf.fill"
        case .developing: "arrow.up.right"
        case .solid: "checkmark.seal.fill"
        case .advanced: "star.fill"
        case .weapon: "bolt.shield.fill"
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .beginner: 0...20
        case .developing: 21...40
        case .solid: 41...60
        case .advanced: 61...80
        case .weapon: 81...100
        }
    }

    var nextTier: SkillTier? {
        switch self {
        case .beginner: .developing
        case .developing: .solid
        case .solid: .advanced
        case .advanced: .weapon
        case .weapon: nil
        }
    }

    /// Progress within the current tier (0.0 to 1.0)
    static func tierProgress(for rating: Int) -> Double {
        let tier = SkillTier(rating: rating)
        let r = tier.range
        let size = Double(r.upperBound - r.lowerBound)
        guard size > 0 else { return 1.0 }
        return min(max(Double(rating - r.lowerBound) / size, 0), 1.0)
    }

    /// Points needed to reach the next tier
    static func pointsToNext(for rating: Int) -> Int {
        let tier = SkillTier(rating: rating)
        return max(tier.range.upperBound - rating + 1, 0)
    }
}
