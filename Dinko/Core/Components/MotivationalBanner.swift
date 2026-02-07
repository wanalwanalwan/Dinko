import SwiftUI

struct MotivationalBanner: View {
    let improvingCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            Text("🔥")
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
        .background(AppColors.bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
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
