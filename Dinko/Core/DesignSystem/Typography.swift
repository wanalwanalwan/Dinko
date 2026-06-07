import SwiftUI

enum AppTypography {
    // MARK: - Headings (Sora)
    static let largeTitle = Font.custom("Sora-Bold", size: 34)
    static let title = Font.custom("Sora-SemiBold", size: 22)
    static let headline = Font.custom("Sora-SemiBold", size: 17)
    static let ratingLarge = Font.custom("Sora-Bold", size: 48)
    static let skillName = Font.custom("Sora-SemiBold", size: 16)

    // MARK: - Stat Numbers (Sora)
    static let statLarge = Font.custom("Sora-Bold", size: 28)
    static let statMedium = Font.custom("Sora-Bold", size: 22)

    // MARK: - Section Headers
    static let sectionLabel = Font.system(size: 11, weight: .semibold, design: .rounded)

    // MARK: - Card Typography
    static let cardTitle = Font.system(size: 15, weight: .bold, design: .rounded)
    static let cardBody = Font.system(size: 13, weight: .medium, design: .rounded)
    static let cardCaption = Font.system(size: 12, design: .rounded)

    // MARK: - Button Labels
    static let buttonLabel = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let buttonLabelSmall = Font.system(size: 12, weight: .semibold, design: .rounded)

    // MARK: - Pill Labels
    static let pillLabel = Font.system(size: 10, weight: .bold, design: .rounded)

    // MARK: - Body (SF Pro — system default)
    static let body = Font.system(.body, design: .default)
    static let callout = Font.system(.callout, design: .default)
    static let caption = Font.system(.caption, design: .default)
    static let ratingBadge = Font.system(size: 14, weight: .bold, design: .default)
    static let trendValue = Font.system(size: 12, weight: .medium, design: .default)
}
