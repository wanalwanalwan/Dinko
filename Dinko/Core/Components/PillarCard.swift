import SwiftUI

/// Compact card showing pillar summary: icon + name + gap count or checkmark.
struct PillarCard: View {
    let summary: SkillPillarSummary
    let isExpanded: Bool
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.xxs) {
                Text(summary.pillar.iconName)
                    .font(.title2)

                Text(summary.pillar.displayName)
                    .font(AppTypography.pillLabel)
                    .foregroundStyle(AppColors.textPrimary)
                    .textCase(.uppercase)

                if summary.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.successGreen)
                } else {
                    Text("\(summary.remainingSkills) gap\(summary.remainingSkills == 1 ? "" : "s")")
                        .font(AppTypography.cardCaption)
                        .foregroundStyle(summary.isCurrentFocus ? AppColors.coral : AppColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .neumorphicRaised(
                intensity: summary.isCurrentFocus ? .standard : .subtle,
                cornerRadius: AppSpacing.cornerRadiusMd
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd)
                    .stroke(
                        summary.isCurrentFocus ? AppColors.primary.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
