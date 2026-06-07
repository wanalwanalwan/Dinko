import Foundation

enum AppSpacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let badgeSize: CGFloat = 44
    static let iconSize: CGFloat = 40
    static let sparklineHeight: CGFloat = 30

    // MARK: - Corner Radii (3 tiers)
    static let cornerRadiusLg: CGFloat = 22
    static let cornerRadiusMd: CGFloat = 14
    static let cornerRadiusSm: CGFloat = 10

    // MARK: - Backward Compatibility Aliases
    static let cardCornerRadius = cornerRadiusLg
    static let heroCornerRadius = cornerRadiusLg
    static let cardCornerRadiusSmall = cornerRadiusMd
    static let neumorphicCornerRadius = cornerRadiusMd
    static let neumorphicCornerRadiusSmall = cornerRadiusSm
}
