import SwiftUI

/// Horizontal bar showing current confidence vs target on a 1-10 scale.
/// Used across Today, Journey, and SkillDetail screens.
struct ConfidenceBar: View {
    let current: Int // 1-10
    let target: Int  // 1-10
    var height: CGFloat = 8
    var showLabels: Bool = true

    private var currentFraction: CGFloat {
        CGFloat(current) / 10.0
    }

    private var targetFraction: CGFloat {
        CGFloat(target) / 10.0
    }

    private var gap: Int {
        max(0, target - current)
    }

    private var isAtTarget: Bool {
        current >= target
    }

    var body: some View {
        VStack(spacing: AppSpacing.xxxs) {
            if showLabels {
                HStack {
                    Text("You: \(current)")
                        .font(AppTypography.pillLabel)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    if isAtTarget {
                        Label("At target", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.pillLabel)
                            .foregroundStyle(AppColors.successGreen)
                    } else {
                        Text("Target: \(target)")
                            .font(AppTypography.pillLabel)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(AppColors.separator)
                        .frame(height: height)

                    // Current fill
                    Capsule()
                        .fill(isAtTarget ? AppColors.successGreen : AppColors.primary)
                        .frame(width: max(height, geo.size.width * currentFraction), height: height)

                    // Target marker
                    if !isAtTarget {
                        Circle()
                            .fill(AppColors.coral)
                            .frame(width: height + 4, height: height + 4)
                            .offset(x: geo.size.width * targetFraction - (height + 4) / 2)
                    }
                }
            }
            .frame(height: height + 4)
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.lg) {
        ConfidenceBar(current: 3, target: 7)
        ConfidenceBar(current: 7, target: 7)
        ConfidenceBar(current: 5, target: 8, showLabels: false)
    }
    .padding()
}
