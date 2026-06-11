import SwiftUI

/// Single-sentence coach insight card with brain icon.
struct CoachInsightCard: View {
    let text: String

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppColors.primary)

            Text(text)
                .font(AppTypography.cardBody)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.sm)
        .neumorphicTinted(color: AppColors.successGreen, tintOpacity: 0.04, borderOpacity: 0.12)
    }
}
