import SwiftUI

enum AppColors {
    // MARK: - Backgrounds (neumorphic surface hierarchy)
    static let background = Color(light: "ECE6DC", dark: "1A2220")
    static let backgroundGray = Color(light: "E4DED4", dark: "1A2220")
    static let cardBackground = Color(light: "F2EDE5", dark: "1A2220")

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(light: "ECE6DC", dark: "1A2220"), Color(light: "E8E2D8", dark: "1A2220")], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Primary (Forest Green — CTA / Interactive)
    static let primary = Color(hex: "4F7A5A")
    static let primaryDark = Color(hex: "3D6248")
    static let primaryLight = Color(hex: "6B9B74")
    static let primaryTint = Color(light: "E8F0E8", dark: "1A2A1E")

    // MARK: - Highlight (Vibrant Green — rewards, success accents)
    static let highlight = Color(hex: "89C36B")
    static let highlightLight = Color(hex: "A3D48A")

    // MARK: - Accent (Charts / Trends / Destructive)
    static let coral = Color(hex: "F07167")

    // MARK: - Success / Improvement
    static let successGreen = Color(hex: "89C36B")
    static let successGreenLight = Color(hex: "A3D48A")
    static let successGreenDark = Color(hex: "6FA354")

    // MARK: - Warning
    static let warningOrange = Color(hex: "F59E0B")

    // MARK: - Text
    static let textPrimary = Color(light: "1F2937", dark: "F4F7FA")
    static let textSecondary = Color(light: "6B7280", dark: "A6B0BC")

    // MARK: - Card Variants
    static let cardBorder = Color(light: "E8EAED", dark: "2A3340")
    static let heroCardBorder = Color(light: "DEE1E6", dark: "323D4A")
    static let achievementCardBackground = Color(light: "FFFBF0", dark: "1F1B14")
    static let achievementCardBorder = Color(light: "F0E4C8", dark: "3D3220")

    // MARK: - Neumorphic Shadows (calibrated for #ECE6DC base)
    static let neumorphicLight = Color(light: "FAF5EE", dark: "243230")
    static let neumorphicDark = Color(light: "C4BCA8", dark: "0E1614")
    static let neumorphicInnerLight = Color(light: "F5EFE7", dark: "202E2C")
    static let neumorphicInnerDark = Color(light: "CCC4B0", dark: "101A18")

    // MARK: - Surfaces & Borders
    static let agentBubble = Color(light: "DDD5C9", dark: "1E2A28")
    static let elevatedSurface = Color(light: "F2EDE5", dark: "1E2A28")
    static let surfaceDark = Color(light: "16181D", dark: "1E2A28")
    static let separator = Color(light: "D0C8BC", dark: "243230")
    static let lockedGray = Color(light: "C7C7CC", dark: "4A4A4A")

    // MARK: - Skill Tiers
    static let tierBlue = Color(hex: "5B9BD5")
    static let tierGold = Color(hex: "F5A623")

    // MARK: - Achievement / Rewards
    static let trophyGold = Color(hex: "FFD84D")

    // MARK: - Drill Type Pills
    static let drillOrange = Color(hex: "F59E0B")
    static let drillPurple = Color(hex: "8B5CF6")

    // MARK: - Achievement Badges
    static let achievementPink = Color(light: "FFD6D6", dark: "4A2020")
    static let achievementBlue = Color(light: "D6EEFF", dark: "1A2E3D")
    static let achievementYellow = Color(light: "FFF6D6", dark: "3D3520")

    // MARK: - Banner
    static let bannerBackground = Color(light: "E0F0E4", dark: "162E1C")

    // MARK: - Splash Gradient
    static let splashGradientStart = Color(hex: "4F7A5A")
    static let splashGradientEnd = Color(hex: "3D6248")

    // MARK: - Calendar Session Indicators
    static let calendarGame = Color(light: "FFE0E0", dark: "3D2020")
    static let calendarDrill = Color(light: "FFF0D6", dark: "3D3220")
    static let calendarToday = Color(hex: "89C36B")

    // MARK: - Overlay
    static let overlayScrim = Color.black

    // MARK: - Ring Gradients
    static let ringGradientStart = Color(hex: "89C36B")
    static let ringGradientEnd = Color(hex: "4F7A5A")
    static let ringTrack = Color(light: "E8EDE8", dark: "1E2820")
}
