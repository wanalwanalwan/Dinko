import SwiftUI

// MARK: - Floating Shadow (shared — softened for lighter feel)

let floatShadow1: (Color, CGFloat, CGFloat) = (.black.opacity(0.04), 6, 2)
let floatShadow2: (Color, CGFloat, CGFloat) = (.black.opacity(0.02), 16, 6)

// MARK: - Hero Card

struct HeroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
            .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
            .shadow(color: floatShadow2.0, radius: floatShadow2.1, x: 0, y: floatShadow2.2)
    }
}

// MARK: - Coach Card

struct CoachCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.sm)
            .background(AppColors.coachCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
            .shadow(color: floatShadow2.0, radius: floatShadow2.1, x: 0, y: floatShadow2.2)
    }
}

// MARK: - Info Card

struct InfoCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
            .shadow(color: floatShadow2.0, radius: floatShadow2.1, x: 0, y: floatShadow2.2)
    }
}

// MARK: - Achievement Card

struct AchievementCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.sm)
            .background(AppColors.achievementCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
            .shadow(color: floatShadow2.0, radius: floatShadow2.1, x: 0, y: floatShadow2.2)
    }
}

// MARK: - View Extensions

extension View {
    func heroCard() -> some View {
        modifier(HeroCardModifier())
    }

    func coachCard() -> some View {
        modifier(CoachCardModifier())
    }

    func infoCard() -> some View {
        modifier(InfoCardModifier())
    }

    func achievementCard() -> some View {
        modifier(AchievementCardModifier())
    }

    /// Bare floating style: no padding, just background + clip + shadow.
    /// Use on views that already handle their own padding.
    func floatingCard(cornerRadius: CGFloat = AppSpacing.cardCornerRadiusSmall) -> some View {
        self
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
            .shadow(color: floatShadow2.0, radius: floatShadow2.1, x: 0, y: floatShadow2.2)
    }
}
