import SwiftUI

struct EmailVerificationView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            CoachMascot(state: .idle, size: 88, animated: true)

            VStack(spacing: AppSpacing.xs) {
                Text("Check your email")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text("We sent a verification link to")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)

                Text(viewModel.verificationEmail)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.teal)
            }

            Text("Tap the link in the email to confirm your account, then come back and sign in.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.coral)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: AppSpacing.sm) {
                Button {
                    Task { await viewModel.resendVerificationEmail() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(AppColors.teal)
                        } else if viewModel.resendCooldown > 0 {
                            Text("Resend in \(viewModel.resendCooldown)s")
                                .font(AppTypography.headline)
                        } else {
                            Text("Resend Email")
                                .font(AppTypography.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.teal)
                .disabled(viewModel.isLoading || viewModel.resendCooldown > 0)

                Button {
                    viewModel.backToSignIn()
                } label: {
                    Text("Back to Sign In")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.teal)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
            Spacer()
        }
        .background(AppColors.background)
    }
}
