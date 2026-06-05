import SwiftUI

struct SkillCard: View {
    let skill: Skill
    let subskillCount: Int
    let rating: Int
    var delta: Int?

    private var tier: SkillTier { SkillTier(rating: rating) }
    private var overallProgress: Double { min(max(Double(rating) / 100.0, 0), 1) }

    @State private var animatedProgress: Double = 0

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 12) {
            // Left side: name + tier/delta
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 4) {
                    Text(tier.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(0.5)

                    if let delta, delta != 0 {
                        Text("\u{00B7}")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.textSecondary)
                        Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                    }
                }
            }

            Spacer(minLength: 4)

            // Right side: rating text + mini ring + chevron
            HStack(spacing: 10) {
                Text("\(rating)%")
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(tier.color)

                // Mini circular progress ring
                ZStack {
                    Circle()
                        .stroke(tier.color.opacity(0.15), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(tier.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 24, height: 24)

                // Chevron — neumorphic inset circle
                ZStack {
                    Circle()
                        .fill(AppColors.background)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(AppColors.background, lineWidth: 0.5)
                                .shadow(
                                    color: AppColors.neumorphicInnerDark.opacity(0.4),
                                    radius: 1.5, x: 1, y: 1
                                )
                                .shadow(
                                    color: AppColors.neumorphicInnerLight.opacity(0.4),
                                    radius: 1.5, x: -1, y: -1
                                )
                                .clipShape(Circle())
                        )

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .floatingCard()
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(AppAnimations.neumorphicPress, value: isPressed)
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
    .init(id: 5, skill: Skill(name: "Backhand Topspin Counter Attack"), subskillCount: 0, rating: 57, delta: 4),
    .init(id: 6, skill: PreviewData.sampleStrategy, subskillCount: 0, rating: 91, delta: nil),
]

#Preview {
    VStack(spacing: 10) {
        ForEach(skillCardPreviewItems) { item in
            SkillCard(
                skill: item.skill,
                subskillCount: item.subskillCount,
                rating: item.rating,
                delta: item.delta
            )
        }
    }
    .padding(.horizontal)
    .background(AppColors.background)
}
