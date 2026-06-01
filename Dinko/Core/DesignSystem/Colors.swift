import SwiftUI

enum AppColors {
    // MARK: - Backgrounds
    static let background = Color(light: "F2EDE6", dark: "111A14")
    static let backgroundGray = Color(light: "EBE5DC", dark: "131517")
    static let cardBackground = Color(light: "FFFFFF", dark: "1A2027")

    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, background], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Primary (Deep Forest Green — CTA / Interactive)
    static let primary = Color(hex: "365B43")
    static let primaryDark = Color(hex: "2A4935")
    static let primaryLight = Color(hex: "5E8C61")
    static let primaryTint = Color(light: "DDEBDD", dark: "1A2A1E")

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
    static let textPrimary = Color(light: "16181D", dark: "F4F7FA")
    static let textSecondary = Color(light: "69707D", dark: "A6B0BC")

    // MARK: - Card Variants
    static let cardBorder = Color(light: "E8EAED", dark: "2A3340")
    static let heroCardBorder = Color(light: "DEE1E6", dark: "323D4A")
    static let coachCardBackground = Color(light: "EBF5ED", dark: "141F17")
    static let coachCardBorder = Color(light: "B8D8C0", dark: "1E3426")
    static let achievementCardBackground = Color(light: "FFFBF0", dark: "1F1B14")
    static let achievementCardBorder = Color(light: "F0E4C8", dark: "3D3220")
    static let notesCardBackground = Color(light: "F0F7F2", dark: "162018")

    // MARK: - Surfaces & Borders
    static let agentBubble = Color(light: "F0F2F5", dark: "222A33")
    static let elevatedSurface = Color(light: "FFFFFF", dark: "222A33")
    static let surfaceDark = Color(light: "16181D", dark: "222A33")
    static let separator = Color(light: "E2E5EA", dark: "2A3340")
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
    static let splashGradientStart = Color(hex: "365B43")
    static let splashGradientEnd = Color(hex: "2A4935")

    // MARK: - Calendar Session Indicators
    static let calendarGame = Color(light: "FFE0E0", dark: "3D2020")
    static let calendarDrill = Color(light: "FFF0D6", dark: "3D3220")
    static let calendarToday = Color(hex: "89C36B")

    // MARK: - Overlay
    static let overlayScrim = Color.black

    // MARK: - Ring Gradients
    static let ringGradientStart = Color(hex: "89C36B")
    static let ringGradientEnd = Color(hex: "365B43")
    static let ringTrack = Color(light: "E8EDE8", dark: "1E2820")
}
