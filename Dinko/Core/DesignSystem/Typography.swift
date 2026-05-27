import SwiftUI

enum AppTypography {
    // MARK: - Headings (Sora)
    static let largeTitle = Font.custom("Sora-Bold", size: 34)
    static let title = Font.custom("Sora-SemiBold", size: 22)
    static let headline = Font.custom("Sora-SemiBold", size: 17)
    static let ratingLarge = Font.custom("Sora-Bold", size: 48)
    static let skillName = Font.custom("Sora-SemiBold", size: 16)

    // MARK: - Body (SF Pro — system default)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let ratingBadge = Font.system(size: 14, weight: .bold, design: .default)
    static let trendValue = Font.system(size: 12, weight: .medium, design: .default)
}
