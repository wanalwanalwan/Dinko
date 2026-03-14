import SwiftUI

struct RatingBadge: View {
    let rating: Int
    var size: CGFloat = 60
    var ringColor: Color = AppColors.teal
    var showCheckmark: Bool = false
    var showLabel: Bool = true

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double { min(max(Double(rating) / 100.0, 0), 1) }
    private var lineWidth: CGFloat { size * 0.1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.separator, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(ringColor)
            } else if showLabel {
                Text("\(rating)%")
                    .font(size > 100 ? AppTypography.ratingLarge : AppTypography.ratingBadge)
                    .foregroundStyle(AppColors.textPrimary)
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
            RatingBadge(rating: 45, ringColor: AppColors.drillOrange)
            RatingBadge(rating: 75, ringColor: AppColors.teal)
            RatingBadge(rating: 100, ringColor: AppColors.teal, showCheckmark: true)
        }
        RatingBadge(rating: 82, size: 160)
    }
}
