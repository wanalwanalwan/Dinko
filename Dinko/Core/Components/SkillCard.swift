import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }

    private var lastUpdatedText: String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: skill.updatedAt),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case 0: return "Last updated today"
        case 1: return "Last updated yesterday"
        default: return "Last updated \(days) days ago"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(skill.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(tier.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tier.color)
                    .padding(.horizontal, AppSpacing.xxs)
                    .padding(.vertical, AppSpacing.xxxs)
                    .background(tier.color.opacity(0.15))
                    .clipShape(Capsule())

                HStack(spacing: AppSpacing.xxxs) {
                    Text(lastUpdatedText)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    if let delta, delta != 0 {
                        Text("·")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.teal)

                        Text(delta > 0 ? "+\(delta)% this week" : "\(delta)% this week")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.teal)
                    }
                }
            }

            Spacer()

            RatingBadge(rating: rating)
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
            rating: 45,
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
