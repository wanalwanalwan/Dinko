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

private struct SkillCardPreviewItem: Identifiable {
    let id: Int
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    let delta: Int?
}

private let skillCardPreviewItems: [SkillCardPreviewItem] = [
    .init(id: 0, skill: PreviewData.sampleServe, subskillCount: 3, rating: 85, delta: 3),
    .init(id: 1, skill: PreviewData.sampleDink, subskillCount: 2, rating: 45, delta: -2),
    .init(id: 2, skill: PreviewData.sampleFootwork, subskillCount: 0, rating: 12, delta: nil),
    .init(id: 3, skill: PreviewData.sampleVolley, subskillCount: 1, rating: 68, delta: 5),
    .init(id: 4, skill: PreviewData.sampleThirdShot, subskillCount: 2, rating: 33, delta: 1),
    .init(id: 5, skill: PreviewData.sampleStrategy, subskillCount: 0, rating: 91, delta: nil),
]

#Preview {
    VStack(spacing: 0) {
        ForEach(skillCardPreviewItems) { item in
            SkillCard(
                skill: item.skill,
                subskillCount: item.subskillCount,
                rating: item.rating,
                delta: item.delta
            )
            if item.id < skillCardPreviewItems.count - 1 {
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
