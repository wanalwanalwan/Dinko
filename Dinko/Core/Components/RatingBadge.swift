import SwiftUI

struct RatingBadge: View {
    let rating: Int
    var size: CGFloat = 60
    var ringColor: Color = AppColors.primary
    var showCheckmark: Bool = false
    var showLabel: Bool = true

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double { min(max(Double(rating) / 100.0, 0), 1) }
    private var lineWidth: CGFloat { size >= 100 ? size * 0.12 : size * 0.1 }
    private var isHero: Bool { size >= 100 }

    var body: some View {
        ZStack {
            // Track ring with subtle inner depth
            Circle()
                .stroke(AppColors.ringTrack, lineWidth: lineWidth)

            // Inner shadow for depth
            if isHero {
                Circle()
                    .stroke(Color.black.opacity(0.04), lineWidth: lineWidth * 0.5)
                    .blur(radius: 2)
                    .padding(lineWidth * 0.25)
            }

            // Gradient progress stroke.
            // startAngle is nudged to -10° so the gradient seam (where dark wraps
            // back to light) falls at 350° — inside the arc's gap between its end
            // and its start. At 0° (path start, visual 12-o'clock after rotation)
            // the gradient is only 10/360 ≈ 3% through, essentially ringGradientStart,
            // so the rounded start-cap is fully light and never clips the dark end.
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            AppColors.ringGradientStart,
                            AppColors.ringGradientEnd
                        ],
                        center: .center,
                        startAngle: .degrees(-10),
                        endAngle: .degrees(350)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Glow behind the stroke end
            if isHero && animatedProgress > 0.05 {
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        ringColor.opacity(0.3),
                        style: StrokeStyle(lineWidth: lineWidth * 1.6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 6)
            }

            // Center content
            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(ringColor)
            } else if showLabel {
                VStack(spacing: isHero ? 2 : 0) {
                    Text("\(rating)")
                        .font(isHero
                            ? .system(size: size * 0.28, weight: .bold, design: .rounded)
                            : AppTypography.ratingBadge
                        )
                        .foregroundStyle(AppColors.textPrimary)

                    if isHero {
                        Text("%")
                            .font(.system(size: size * 0.1, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: rating) {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = targetProgress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showCheckmark ? "Completed" : "\(rating) percent rating")
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            RatingBadge(rating: 0)
            RatingBadge(rating: 45, ringColor: AppColors.primaryLight)
            RatingBadge(rating: 75, ringColor: AppColors.primary)
            RatingBadge(rating: 100, ringColor: AppColors.primary, showCheckmark: true)
        }
        RatingBadge(rating: 82, size: 160)
    }
}
