import SwiftUI

struct SkillCard: View {
    let skill: SkillPreview

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            skillIcon
            skillInfo
            Spacer()
            trailingSection
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var skillIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.teal.opacity(0.15))
                .frame(width: AppSpacing.iconSize, height: AppSpacing.iconSize)

            Image(systemName: skill.iconName)
                .font(.body)
                .foregroundStyle(AppColors.teal)
        }
    }

    private var skillInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            HStack(spacing: AppSpacing.xxs) {
                Text(skill.name)
                    .font(AppTypography.skillName)
                    .foregroundStyle(AppColors.textPrimary)

                trendIndicator
            }

            Text("\(skill.completedCheckers)/\(skill.totalCheckers) checkers")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            ProgressBar(progress: skill.checkerProgress)
        }
    }

    private var trendIndicator: some View {
        HStack(spacing: 2) {
            if skill.trendChange > 0 {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(AppColors.successGreen)
                Text("+\(skill.trendChange)")
                    .font(AppTypography.trendValue)
                    .foregroundStyle(AppColors.successGreen)
            } else if skill.trendChange < 0 {
                Image(systemName: "arrow.down.right")
                    .font(.caption2)
                    .foregroundStyle(AppColors.coral)
                Text("\(skill.trendChange)")
                    .font(AppTypography.trendValue)
                    .foregroundStyle(AppColors.coral)
            } else {
                Text("—")
                    .font(AppTypography.trendValue)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var trailingSection: some View {
        HStack(spacing: AppSpacing.xxs) {
            RatingBadge(rating: skill.rating)
            SparklineChart(data: skill.ratingHistory)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SkillCard(skill: PreviewData.serveSkill)
        SkillCard(skill: PreviewData.dinkSkill)
        SkillCard(skill: PreviewData.volleySkill)
    }
    .padding()
    .background(AppColors.background)
}
