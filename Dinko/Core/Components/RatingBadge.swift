import SwiftUI

struct RatingBadge: View {
    let rating: Int
    var size: CGFloat = 60
    var ringColor: Color = AppColors.teal
    var showCheckmark: Bool = false

    private var progress: Double { min(max(Double(rating) / 100.0, 0), 1) }
    private var lineWidth: CGFloat { size * 0.1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if showCheckmark {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(ringColor)
            } else {
                Text("\(rating)%")
                    .font(size > 100 ? AppTypography.ratingLarge : AppTypography.ratingBadge)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            RatingBadge(rating: 0)
            RatingBadge(rating: 45, ringColor: .orange)
            RatingBadge(rating: 75, ringColor: AppColors.teal)
            RatingBadge(rating: 100, ringColor: AppColors.teal, showCheckmark: true)
        }
        RatingBadge(rating: 82, size: 160)
    }
}
