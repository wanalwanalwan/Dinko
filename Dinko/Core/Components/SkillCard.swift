import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }
    private var tierProgress: Double { SkillTier.tierProgress(for: rating) }
    private var pointsToNext: Int { SkillTier.pointsToNext(for: rating) }

    @State private var animatedTierProgress: Double = 0

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            // Progress ring with category icon
            ZStack {
                RatingBadge(
                    rating: rating,
                    size: 56,
                    ringColor: tier.color,
                    showLabel: false
                )

                Image(systemName: skill.category.sfSymbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(tier.color)
            }
            .frame(width: 56, height: 56)

            // Skill info
            VStack(alignment: .leading, spacing: 6) {
                // Name + percentage
                HStack(alignment: .firstTextBaseline) {
                    Text(skill.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("\(rating)%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(tier.color)
                }

                // Tier badge + delta
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: tier.sfSymbol)
                            .font(.system(size: 8, weight: .bold))
                        Text(tier.displayName.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(tier.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tier.color.opacity(0.12))
                    .clipShape(Capsule())

                    if let delta, delta != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 8, weight: .bold))
                            Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                    }
                }

                // Tier progress bar (XP to next level)
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(tier.color.opacity(0.12))

                            Capsule()
                                .fill(tier.color.gradient)
                                .frame(width: max(geo.size.width * animatedTierProgress, 0))
                        }
                    }
                    .frame(height: 5)
                    .clipShape(Capsule())

                    if let next = tier.nextTier {
                        Text("\(pointsToNext) to \(next.displayName)")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize()
                    } else {
                        Text("Mastered")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(tier.color)
                            .fixedSize()
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedTierProgress = tierProgress
            }
        }
        .onChange(of: rating) {
            withAnimation(AppAnimations.springSmooth) {
                animatedTierProgress = tierProgress
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name), \(tier.displayName), \(rating) percent\(delta.map { $0 > 0 ? ", up \($0) percent" : $0 < 0 ? ", down \(abs($0)) percent" : "" } ?? "")")
    }
}

#Preview {
    VStack(spacing: 12) {
        SkillCard(
            skill: PreviewData.sampleServe,
            subskillCount: 3,
            rating: 85,
            delta: 3
        )
        SkillCard(
            skill: PreviewData.sampleDink,
            subskillCount: 2,
            rating: 45,
            delta: -2
        )
        SkillCard(
            skill: PreviewData.sampleFootwork,
            subskillCount: 0,
            rating: 12,
            delta: nil
        )
    }
    .padding()
    .background(AppColors.background)
}
