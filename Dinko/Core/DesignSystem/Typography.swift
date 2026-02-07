import SwiftUI

enum AppTypography {
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let ratingLarge = Font.system(size: 48, weight: .bold, design: .rounded)
    static let ratingBadge = Font.system(size: 14, weight: .bold, design: .rounded)
    static let skillName = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let trendValue = Font.system(size: 12, weight: .medium, design: .rounded)
}
