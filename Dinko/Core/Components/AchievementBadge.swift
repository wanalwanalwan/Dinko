import SwiftUI

struct AchievementBadge: View {
    let name: String
    let iconName: String
    let isUnlocked: Bool
    var badgeColor: Color = AppColors.achievementPink

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            ZStack {
                RoundedRectangle(cornerRadius: AppSpacing.xs)
                    .fill(isUnlocked ? badgeColor : AppColors.lockedGray.opacity(0.3))
                    .frame(width: 64, height: 64)

                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? AppColors.textPrimary : AppColors.lockedGray)
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
}
