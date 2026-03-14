import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }
    private var progress: Double { min(max(Double(rating) / 100.0, 0), 1) }

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.xs) {
                // Category icon in rounded square
                Image(systemName: skill.category.sfSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(tier.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                // Skill info
                VStack(alignment: .leading, spacing: 4) {
                    Text(skill.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 6) {
                        // Tier badge with icon
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

                        // Delta
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
                }

                Spacer()

                // Rating
                Text("\(rating)%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tier.color)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tier.color.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(tier.color.gradient)
                        .frame(width: geo.size.width * animatedProgress, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, AppSpacing.xs)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = progress
            }
        }
        .onChange(of: rating) {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = progress
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
