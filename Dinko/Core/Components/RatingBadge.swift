import SwiftUI

struct RatingBadge: View {
    let rating: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.teal)
                .frame(width: AppSpacing.badgeSize, height: AppSpacing.badgeSize)

            Text("\(rating)%")
                .font(AppTypography.ratingBadge)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        RatingBadge(rating: 0)
        RatingBadge(rating: 50)
        RatingBadge(rating: 75)
        RatingBadge(rating: 100)
    }
}
