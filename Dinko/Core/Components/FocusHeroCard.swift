import SwiftUI

/// Hero card showing today's recommended focus skill.
/// Takes up 40-50% of viewport. Shows skill name, pillar, session type,
/// confidence vs target, gap, reason, and action buttons.
struct FocusHeroCard: View {
    let focus: RecommendedFocus
    var onStart: () -> Void = {}
    var onNotToday: () -> Void = {}
    var onSwap: () -> Void = {}

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Pillar + Session type header
            HStack {
                Text(focus.pillar.iconName)
                    .font(.title2)
                Text(focus.pillar.displayName)
                    .font(AppTypography.pillLabel)
                    .foregroundStyle(AppColors.textSecondary)
                    .textCase(.uppercase)
                Spacer()
                sessionTypePill
            }

            // Skill name
            Text(focus.skill.name)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Confidence bar
            ConfidenceBar(current: focus.currentConfidence, target: focus.targetConfidence)
                .padding(.vertical, AppSpacing.xxxs)

            // Gap callout
            if focus.gap > 0 {
                Text("Gap of \(focus.gap) to reach your target")
                    .font(AppTypography.cardCaption)
                    .foregroundStyle(AppColors.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Reason
            Text(focus.reason)
                .font(AppTypography.cardBody)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            // Action buttons
            HStack(spacing: AppSpacing.xxs) {
                Button(action: onStart) {
                    Label("Start Session", systemImage: "play.fill")
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }

                Button(action: onNotToday) {
                    Text("Not today")
                        .font(AppTypography.buttonLabelSmall)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, AppSpacing.xs)
                        .padding(.horizontal, AppSpacing.sm)
                }

                Button(action: onSwap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                        .padding(AppSpacing.xs)
                        .background(AppColors.primaryTint)
                        .clipShape(Circle())
                }
            }
            .padding(.top, AppSpacing.xxxs)
        }
        .padding(AppSpacing.md)
        .neumorphicRaised(intensity: .prominent)
    }

    private var sessionTypePill: some View {
        HStack(spacing: 4) {
            Image(systemName: focus.sessionType.iconName)
                .font(.system(size: 10, weight: .semibold))
            Text(focus.sessionType.shortLabel)
                .font(AppTypography.pillLabel)
        }
        .foregroundStyle(AppColors.primary)
        .padding(.horizontal, AppSpacing.xxs)
        .padding(.vertical, 4)
        .background(AppColors.primaryTint)
        .clipShape(Capsule())
    }
}
