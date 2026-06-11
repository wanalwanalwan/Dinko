import SwiftUI

/// Row showing a skill's confidence vs target in the Journey view.
/// Columns: skill name | You | Target | gap/checkmark | optional NOW marker
struct SkillConfidenceRow: View {
    let info: JourneySkillInfo
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.xxs) {
                // Skill name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(info.name)
                            .font(AppTypography.cardBody)
                            .foregroundStyle(info.isLocked ? AppColors.lockedGray : AppColors.textPrimary)

                        if info.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.lockedGray)
                        }
                    }

                    if info.isLocked, let prereq = info.unmetPrerequisites.first {
                        Text("Requires \(prereq)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppColors.lockedGray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // You column
                Text("\(info.currentConfidence)")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(info.isLocked ? AppColors.lockedGray : AppColors.textPrimary)
                    .frame(width: 30, alignment: .center)

                // Target column
                Text("\(info.targetConfidence)")
                    .font(AppTypography.cardCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 30, alignment: .center)

                // Gap or checkmark
                if info.gap == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.successGreen)
                        .frame(width: 30)
                } else {
                    Text("-\(info.gap)")
                        .font(AppTypography.cardBody)
                        .foregroundStyle(AppColors.coral)
                        .frame(width: 30, alignment: .center)
                }

                // NOW marker
                if info.isCurrentFocus {
                    Text("NOW")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(width: 36)
                }
            }
            .padding(.vertical, AppSpacing.xxs)
            .padding(.horizontal, AppSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(info.isLocked ? 0.6 : 1.0)
    }
}
