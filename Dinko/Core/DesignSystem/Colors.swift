import SwiftUI

enum AppColors {
    // MARK: - Backgrounds
    static let background = Color(light: "F2F7F3", dark: "111A14")
    static let backgroundGray = Color(light: "F0F1F2", dark: "131517")
    static let cardBackground = Color(light: "FFFFFF", dark: "1A2027")

    /// Gradient from light green at top fading to neutral gray at bottom
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, backgroundGray],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Primary (Athletic Green — CTA / Interactive)
    static let primary = Color(hex: "1E6B3A")
    static let primaryDark = Color(hex: "155A2E")
    static let primaryLight = Color(hex: "2F8F4E")
    static let primaryTint = Color(light: "E0F0E5", dark: "122618")

    // MARK: - Accent (Charts / Trends / Destructive)
    static let coral = Color(hex: "F07167")

    // MARK: - Success / Improvement (Bright Progress Green)
    static let successGreen = Color(hex: "8EDB3A")
    static let successGreenLight = Color(hex: "A8E86A")
    static let successGreenDark = Color(hex: "6FB82E")

    // MARK: - Warning
    static let warningOrange = Color(hex: "F59E0B")

    // MARK: - Text
    static let textPrimary = Color(light: "16181D", dark: "F4F7FA")
    static let textSecondary = Color(light: "69707D", dark: "A6B0BC")

    // MARK: - Surfaces & Borders
    static let agentBubble = Color(light: "F0F2F5", dark: "222A33")
    static let elevatedSurface = Color(light: "FFFFFF", dark: "222A33")
    static let surfaceDark = Color(light: "16181D", dark: "222A33")
    static let separator = Color(light: "E2E5EA", dark: "2A3340")
    static let lockedGray = Color(light: "C7C7CC", dark: "4A4A4A")

    // MARK: - Skill Tiers
    static let tierBlue = Color(hex: "5B9BD5")
    static let tierGold = Color(hex: "F5A623")

    // MARK: - Achievement / Rewards (Yellow)
    static let trophyGold = Color(hex: "FFD84D")

    // MARK: - Drill Type Pills
    static let drillOrange = Color(hex: "F59E0B")
    static let drillPurple = Color(hex: "8B5CF6")

    // MARK: - Achievement Badges
    static let achievementPink = Color(light: "FFD6D6", dark: "4A2020")
    static let achievementBlue = Color(light: "D6EEFF", dark: "1A2E3D")
    static let achievementYellow = Color(light: "FFF6D6", dark: "3D3520")

    // MARK: - Banner
    static let bannerBackground = Color(light: "E8F5EC", dark: "162E1C")

    // MARK: - Splash Gradient
    static let splashGradientStart = Color(hex: "1E6B3A")
    static let splashGradientEnd = Color(hex: "155A2E")

    // MARK: - Overlay
    static let overlayScrim = Color.black
}
