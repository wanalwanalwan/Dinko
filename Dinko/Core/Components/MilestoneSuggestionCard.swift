import SwiftUI

/// Card suggesting a confidence update after completing a learning cycle.
/// "Brine suggests updating Resets 3->4". Accept/Adjust/Keep Current.
struct MilestoneSuggestionCard: View {
    let suggestion: ConfidenceSuggestion
    var onAccept: () -> Void = {}
    var onAdjust: () -> Void = {}
    var onKeep: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Header
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.tierGold)

                Text("Milestone reached!")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Suggestion text
            HStack(spacing: 4) {
                Text("Update")
                    .foregroundStyle(AppColors.textSecondary)
                Text(suggestion.skillName)
                    .foregroundStyle(AppColors.textPrimary)
                    .fontWeight(.semibold)
                Text("\(suggestion.currentConfidence)")
                    .foregroundStyle(AppColors.coral)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(suggestion.suggestedConfidence)")
                    .foregroundStyle(AppColors.successGreen)
                    .fontWeight(.semibold)
            }
            .font(AppTypography.cardBody)

            // Evidence bullets
            ForEach(suggestion.evidence, id: \.self) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppColors.successGreen)
                        .frame(width: 4, height: 4)
                    Text(item)
                        .font(AppTypography.cardCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            // Action buttons
            HStack(spacing: AppSpacing.xxs) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
                }

                Button(action: onAdjust) {
                    Text("Adjust")
                        .font(AppTypography.buttonLabelSmall)
                        .foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppColors.primaryTint)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm))
                }

                Button(action: onKeep) {
                    Text("Keep")
                        .font(AppTypography.buttonLabelSmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.xxs)
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
            .padding(.top, AppSpacing.xxxs)
        }
        .padding(AppSpacing.sm)
        .neumorphicTinted(color: AppColors.tierGold, tintOpacity: 0.04, borderOpacity: 0.15)
    }
}
