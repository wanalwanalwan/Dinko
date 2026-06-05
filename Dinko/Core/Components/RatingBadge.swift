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
            // Neumorphic bezel for hero size
            if isHero {
                Circle()
                    .fill(AppColors.background)
                    .shadow(
                        color: AppColors.neumorphicLight.opacity(0.9),
                        radius: 10, x: -6, y: -6
                    )
                    .shadow(
                        color: AppColors.neumorphicDark.opacity(0.6),
                        radius: 10, x: 6, y: 6
                    )
            }

            // Track ring with inset shadow appearance
            Circle()
                .stroke(AppColors.ringTrack, lineWidth: lineWidth)
                .overlay(
                    Circle()
                        .stroke(AppColors.background, lineWidth: 0.5)
                        .shadow(
                            color: AppColors.neumorphicInnerDark.opacity(0.3),
                            radius: 2, x: 1, y: 1
                        )
                        .shadow(
                            color: AppColors.neumorphicInnerLight.opacity(0.3),
                            radius: 2, x: -1, y: -1
                        )
                        .clipShape(Circle())
                )

            // Gradient progress stroke
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
    .background(AppColors.background)
}
