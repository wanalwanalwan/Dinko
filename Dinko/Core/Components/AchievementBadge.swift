import SwiftUI

struct AchievementBadge: View {
    let name: String
    let iconName: String
    let isUnlocked: Bool
    var badgeColor: Color = AppColors.achievementPink

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            if isUnlocked {
                // Neumorphic raised with subtle tinted overlay
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.xs)
                        .fill(AppColors.background)
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: AppColors.neumorphicLight.opacity(0.8),
                            radius: 5, x: -3, y: -3
                        )
                        .shadow(
                            color: AppColors.neumorphicDark.opacity(0.4),
                            radius: 5, x: 3, y: 3
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.xs)
                                .fill(badgeColor.opacity(0.2))
                        )

                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(AppColors.textPrimary)
                }
            } else {
                // Neumorphic inset (pushed down, muted)
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.xs)
                        .fill(AppColors.background)
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSpacing.xs)
                                .stroke(AppColors.background, lineWidth: 0.5)
                                .shadow(
                                    color: AppColors.neumorphicInnerDark.opacity(0.5),
                                    radius: 3, x: 2, y: 2
                                )
                                .shadow(
                                    color: AppColors.neumorphicInnerLight.opacity(0.5),
                                    radius: 3, x: -2, y: -2
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        )

                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(AppColors.lockedGray)
                }
            }

            Text(name)
                .font(AppTypography.caption)
                .foregroundStyle(isUnlocked ? AppColors.textPrimary : AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 72)
    }
}

#Preview {
    HStack(spacing: 16) {
        AchievementBadge(name: "Getting Started", iconName: "star.fill", isUnlocked: true, badgeColor: AppColors.achievementPink)
        AchievementBadge(name: "Solid Player", iconName: "shield.fill", isUnlocked: true, badgeColor: AppColors.achievementBlue)
        AchievementBadge(name: "Advanced", iconName: "trophy.fill", isUnlocked: false, badgeColor: AppColors.achievementYellow)
    }
    .padding()
    .background(AppColors.background)
}
