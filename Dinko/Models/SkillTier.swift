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
}
