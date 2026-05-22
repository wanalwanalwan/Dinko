import SwiftUI

struct SessionTypeSheet: View {
    let onSelectType: (SessionType) -> Void

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Capsule()
                .fill(AppColors.separator)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.xs)

            Text("Log Session")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(SessionType.allCases) { type in
                    SessionTypeCard(type: type) {
                        onSelectType(type)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.sm)

            Spacer()
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.hidden)
    }
}

private struct SessionTypeCard: View {
    let type: SessionType
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: type.iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(AppColors.teal)

                Text(type.displayName)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text(type.description)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .padding(.horizontal, AppSpacing.xxs)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(AppColors.teal.opacity(isPressed ? 1 : 0.15), lineWidth: isPressed ? 2 : 1)
            )
            .scaleEffect(isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SessionTypeSheet { type in
                print("Selected: \(type)")
            }
        }
}
