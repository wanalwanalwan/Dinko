import SwiftUI

// MARK: - Hero Card

struct HeroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius)
                    .stroke(AppColors.heroCardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Coach Card

struct CoachCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.sm)
            .background(AppColors.coachCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall)
                    .stroke(AppColors.coachCardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Info Card

struct InfoCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.xs)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall)
                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - Achievement Card

struct AchievementCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.sm)
            .background(AppColors.achievementCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall)
                    .stroke(AppColors.achievementCardBorder, lineWidth: 1)
            )
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
}
