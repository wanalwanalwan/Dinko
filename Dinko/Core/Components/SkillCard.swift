import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }
    private var overallProgress: Double { min(max(Double(rating) / 100.0, 0), 1) }

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Row 1: Skill name + percentage
            HStack(alignment: .firstTextBaseline) {
                Text(skill.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(rating)%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tier.color)
            }

            // Row 2: Tier badge
            Text(tier.displayName.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .tracking(0.5)

            // Row 3: Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tier.color.opacity(0.12))

                    Capsule()
                        .fill(tier.color.gradient)
                        .frame(width: max(geo.size.width * animatedProgress, 0))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            // Row 4: Delta
            if let delta, delta != 0 {
                Text(delta > 0 ? "+\(delta)% this week" : "\(delta)% this week")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
            }
        }
        .padding(AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxxs)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = overallProgress
            }
        }
        .onChange(of: rating) {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = overallProgress
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(skill.name), \(tier.displayName), \(rating) percent\(delta.map { $0 > 0 ? ", up \($0) percent" : $0 < 0 ? ", down \(abs($0)) percent" : "" } ?? "")")
    }
}

#Preview {
    VStack(spacing: 16) {
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
