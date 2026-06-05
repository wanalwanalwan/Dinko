import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Log Session")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.primary)
            .clipShape(Capsule())
            .shadow(
                color: AppColors.neumorphicLight.opacity(0.6),
                radius: isPressed ? 3 : 6,
                x: isPressed ? -2 : -4,
                y: isPressed ? -2 : -4
            )
            .shadow(
                color: AppColors.neumorphicDark.opacity(0.5),
                radius: isPressed ? 3 : 6,
                x: isPressed ? 2 : 4,
                y: isPressed ? 2 : 4
            )
            .shadow(color: AppColors.primary.opacity(0.35), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(AppAnimations.neumorphicPress, value: isPressed)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AppColors.background.ignoresSafeArea()
        VStack {
            Spacer()
            FloatingActionButton { }
                .padding(.bottom, 60)
        }
    }
}
