import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

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
            .shadow(color: AppColors.primary.opacity(0.4), radius: 8, x: 0, y: 4)
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
