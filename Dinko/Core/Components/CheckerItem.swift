import SwiftUI

struct CheckerItem: View {
    let name: String
    let isCompleted: Bool
    var onToggle: (() -> Void)?

    var body: some View {
        Button(action: { onToggle?() }) {
            HStack(spacing: AppSpacing.xs) {
                // Neumorphic toggle circle
                ZStack {
                    if isCompleted {
                        // Inset (concave) when completed
                        Circle()
                            .fill(AppColors.background)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.background, lineWidth: 0.5)
                                    .shadow(
                                        color: AppColors.neumorphicInnerDark.opacity(0.5),
                                        radius: 2, x: 1, y: 1
                                    )
                                    .shadow(
                                        color: AppColors.neumorphicInnerLight.opacity(0.5),
                                        radius: 2, x: -1, y: -1
                                    )
                                    .clipShape(Circle())
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(AppColors.successGreen)
                            )
                    } else {
                        // Raised (convex) when unchecked
                        Circle()
                            .fill(AppColors.background)
                            .frame(width: 28, height: 28)
                            .shadow(
                                color: AppColors.neumorphicLight.opacity(0.7),
                                radius: 3, x: -2, y: -2
                            )
                            .shadow(
                                color: AppColors.neumorphicDark.opacity(0.35),
                                radius: 3, x: 2, y: 2
                            )
                    }
                }
                .animation(AppAnimations.neumorphicToggle, value: isCompleted)

                Text(name)
                    .font(AppTypography.body)
                    .foregroundStyle(isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                    .strikethrough(isCompleted, color: AppColors.textSecondary)

                Spacer()
            }
            .padding(.vertical, AppSpacing.xxs)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        CheckerItem(name: "Consistent deep serve", isCompleted: true)
        CheckerItem(name: "Spin serve", isCompleted: false)
        CheckerItem(name: "Placement accuracy", isCompleted: true)
        CheckerItem(name: "Power serve", isCompleted: false)
    }
    .padding()
    .background(AppColors.background)
}
