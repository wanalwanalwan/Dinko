import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(skill.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(tier.displayName)
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tier.color)

                ProgressBar(progress: Double(rating) / 100.0)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                Text(skill.iconName)
                    .font(.title2)

                if let delta {
                    if delta > 0 {
                        Text("+\(delta)%")
                            .font(AppTypography.trendValue)
                            .foregroundStyle(AppColors.successGreen)
                    } else if delta < 0 {
                        Text("\(delta)%")
                            .font(AppTypography.trendValue)
                            .foregroundStyle(AppColors.coral)
                    }
                }
            }
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
            rating: 75,
            delta: 3
        )
        SkillCard(
            skill: PreviewData.sampleDink,
            subskillCount: 2,
            rating: 80,
            delta: -2
        )
        SkillCard(
            skill: PreviewData.sampleVolley,
            subskillCount: 0,
            rating: 0,
            delta: nil
        )
    }
    .padding()
    .background(AppColors.background)
}
