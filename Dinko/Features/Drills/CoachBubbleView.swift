import SwiftUI

struct CoachBubbleView: View {
    let tip: String
    let isCelebrating: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            CoachMascot(state: isCelebrating ? .celebrating : .idle, size: 56, animated: true)
                .offset(y: -4)

            Text(tip)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    BubbleShape()
                        .fill(AppColors.cardBackground)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.sm)
    }
}

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 14
        let tailWidth: CGFloat = 10
        let tailHeight: CGFloat = 8
        let tailX: CGFloat = 18

        var path = Path()

        // Main rounded rect
        let mainRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height - tailHeight)
        path.addRoundedRect(in: mainRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        // Triangle tail pointing down-left
        path.move(to: CGPoint(x: tailX, y: rect.height - tailHeight))
        path.addLine(to: CGPoint(x: tailX - tailWidth / 2, y: rect.height))
        path.addLine(to: CGPoint(x: tailX + tailWidth, y: rect.height - tailHeight))
        path.closeSubpath()

        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        CoachBubbleView(tip: "Focus on form over power today!", isCelebrating: false)
        CoachBubbleView(tip: "Nice work! Keep that momentum going!", isCelebrating: true)
    }
    .padding()
    .background(AppColors.background)
}
