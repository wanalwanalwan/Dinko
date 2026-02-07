import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(skill.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Image(systemName: skill.iconName)
                    .font(.title2)
                    .foregroundStyle(AppColors.teal)
            }

            Text("\(subskillCount) subskills")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            ProgressBar(progress: Double(rating) / 100.0)

            Text("\(rating)%")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

#Preview {
    VStack(spacing: 12) {
        SkillCard(
            skill: PreviewData.sampleServe,
            subskillCount: 3,
            rating: 75
        )
        SkillCard(
            skill: PreviewData.sampleDink,
            subskillCount: 2,
            rating: 80
        )
        SkillCard(
            skill: PreviewData.sampleVolley,
            subskillCount: 0,
            rating: 0
        )
    }
    .padding()
    .background(AppColors.background)
}
