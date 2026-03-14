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
        VStack(alignment: .leading, spacing: 3) {
            // Primary row: dot + name + progress bar + percentage
            HStack(spacing: 10) {
                Circle()
                    .fill(tier.color)
                    .frame(width: 8, height: 8)

                Text(skill.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(tier.color.opacity(0.12))

                        Capsule()
                            .fill(tier.color.gradient)
                            .frame(width: max(geo.size.width * animatedProgress, 0))
                    }
                }
                .frame(width: 56, height: 4)
                .clipShape(Capsule())

                Text("\(rating)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tier.color)
                    .frame(width: 40, alignment: .trailing)
            }

            // Secondary row: tier label + delta
            HStack(spacing: 4) {
                Text(tier.displayName.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(0.5)

                if let delta, delta != 0 {
                    Text("\u{00B7}")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                }
            }
            .padding(.leading, 18) // align with skill name (8 dot + 10 spacing)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
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
    VStack(spacing: 0) {
        ForEach(Array([
            (PreviewData.sampleServe, 3, 85, Optional(3)),
            (PreviewData.sampleDink, 2, 45, Optional(-2)),
            (PreviewData.sampleFootwork, 0, 12, nil as Int?),
            (PreviewData.sampleVolley, 1, 68, Optional(5)),
            (PreviewData.sampleThirdShot, 2, 33, Optional(1)),
            (PreviewData.sampleStrategy, 0, 91, nil as Int?),
        ].enumerated()), id: \.offset) { index, item in
            SkillCard(
                skill: item.0,
                subskillCount: item.1,
                rating: item.2,
                delta: item.3
            )
            if index < 5 {
                Divider()
                    .padding(.leading, 34)
            }
        }
    }
    .background(AppColors.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    .padding()
    .background(AppColors.background)
}
