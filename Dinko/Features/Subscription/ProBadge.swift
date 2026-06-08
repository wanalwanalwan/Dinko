import SwiftUI

struct ProBadge: View {
    var fontSize: CGFloat = 10

    var body: some View {
        Text("PRO")
            .font(.system(size: fontSize, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
    }
}
