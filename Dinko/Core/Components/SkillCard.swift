import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Left: progress ring with category icon inside
            ZStack {
                Circle()
                    .fill(tier.color.opacity(0.1))

                RatingBadge(
                    rating: rating,
                    size: 52,
                    ringColor: tier.color,
                    showLabel: false
                )

                Text(skill.category.iconName)
                    .font(.system(size: 20))
            }
            .frame(width: 52, height: 52)

            // Center: skill info
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                HStack(spacing: AppSpacing.xxs) {
                    // Tier badge
                    Text(tier.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(tier.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(tier.color.opacity(0.12))
                        .clipShape(Capsule())

                    // Delta indicator
                    if let delta, delta != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .semibold))
                            Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((delta > 0 ? AppColors.successGreen : AppColors.coral).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            // Right: rating percentage + chevron
            VStack(spacing: 2) {
                Text("\(rating)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(tier.color)
                Text("%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name), \(tier.displayName), \(rating) percent\(delta.map { $0 > 0 ? ", up \($0) percent this week" : $0 < 0 ? ", down \(abs($0)) percent this week" : "" } ?? "")")
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
            rating: 12,
            delta: nil
        )
    }
    .padding()
    .background(AppColors.background)
}
