import SwiftUI

struct MotivationalBanner: View {
    let improvingCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text("\u{1F525}")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(improvingCount) skill\(improvingCount == 1 ? "" : "s") improving!")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("Keep up the great work!")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(AppColors.successGreen.opacity(0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(
            color: AppColors.neumorphicLight.opacity(0.8),
            radius: 8, x: -5, y: -5
        )
        .shadow(
            color: AppColors.neumorphicDark.opacity(0.5),
            radius: 8, x: 5, y: 5
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        MotivationalBanner(improvingCount: 4)
        MotivationalBanner(improvingCount: 1)
    }
    .padding()
    .background(AppColors.background)
}
