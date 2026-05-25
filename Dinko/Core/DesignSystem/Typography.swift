import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default, weight: .bold)
    static let title = Font.system(.title2, design: .default, weight: .semibold)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let ratingLarge = Font.system(size: 48, weight: .bold, design: .default)
    static let ratingBadge = Font.system(size: 14, weight: .bold, design: .default)
    static let skillName = Font.system(size: 16, weight: .semibold, design: .default)
    static let trendValue = Font.system(size: 12, weight: .medium, design: .default)
}
