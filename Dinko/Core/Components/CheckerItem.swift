import SwiftUI

struct CheckerItem: View {
    let name: String
    let isCompleted: Bool
    var onToggle: (() -> Void)?

    var body: some View {
        Button(action: { onToggle?() }) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? AppColors.successGreen : AppColors.lockedGray)

                Text(name)
                    .font(AppTypography.body)
                    .foregroundStyle(isCompleted ? AppColors.teal : AppColors.textPrimary)
                    .italic(isCompleted)

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
}
