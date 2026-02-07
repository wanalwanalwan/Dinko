import SwiftUI

struct RatingBadge: View {
    let rating: Int
    var size: CGFloat = 60

    private var progress: Double { min(max(Double(rating) / 100.0, 0), 1) }
    private var lineWidth: CGFloat { size * 0.1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.teal, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(rating)%")
                .font(size > 100 ? AppTypography.ratingLarge : AppTypography.ratingBadge)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            RatingBadge(rating: 0)
            RatingBadge(rating: 45)
            RatingBadge(rating: 75)
            RatingBadge(rating: 100)
        }
        RatingBadge(rating: 82, size: 160)
    }
}
