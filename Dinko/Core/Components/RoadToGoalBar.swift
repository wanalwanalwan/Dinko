import SwiftUI

/// Horizontal progress bar: "X of Y skills at target"
struct RoadToGoalBar: View {
    let skillsAtTarget: Int
    let totalSkills: Int
    let goalDUPR: String

    private var fraction: CGFloat {
        guard totalSkills > 0 else { return 0 }
        return CGFloat(skillsAtTarget) / CGFloat(totalSkills)
    }

    var body: some View {
        VStack(spacing: AppSpacing.xxs) {
            HStack {
                Text("Road to \(goalDUPR)")
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(skillsAtTarget)/\(totalSkills) at target")
                    .font(AppTypography.cardCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.separator)
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.successGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * fraction), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(AppSpacing.sm)
        .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
    }
}
