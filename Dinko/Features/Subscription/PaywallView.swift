import SwiftUI

// TODO: Re-enable RevenueCat paywall later
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.primary)

            Text("Subscriptions Coming Soon")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Premium features are unlocked for testing.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                .padding(.horizontal, AppSpacing.md)

            Spacer()
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
    }
}
