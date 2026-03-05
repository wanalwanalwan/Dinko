import SwiftUI

struct CompletedSkillCardView: View {
    let skill: CompletedSkillItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xxxs) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.successGreen)

                Text("Skill Completed")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.successGreen)
            }

            Text(skill.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text("Completed in \(skill.daysToComplete) day\(skill.daysToComplete == 1 ? "" : "s")")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            if !skill.subskills.isEmpty {
                Text("\(skill.subskills.count) subskill\(skill.subskills.count == 1 ? "" : "s") mastered")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.successGreen.opacity(0.8))
            }
        }
        .padding(AppSpacing.sm)
        .frame(width: 220, alignment: .leading)
        .background(AppColors.successGreen.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}
