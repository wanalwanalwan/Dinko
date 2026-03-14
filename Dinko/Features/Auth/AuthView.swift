import SwiftUI

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                    .frame(height: 40)

                // Logo / Branding
                VStack(spacing: AppSpacing.xxs) {
                    CoachMascot(state: .idle, size: 72, animated: true)

                    Text("DinkIt")
                        .font(AppTypography.largeTitle)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Your AI pickleball coach")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
                    .frame(height: 20)

                // Form
                VStack(spacing: AppSpacing.sm) {
                    if viewModel.isSignUp {
                        TextField("First Name", text: $viewModel.firstName)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .padding(AppSpacing.xs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        TextField("Last Name", text: $viewModel.lastName)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                            .padding(AppSpacing.xs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    TextField("Email", text: $viewModel.email)
                        .textContentType(viewModel.isSignUp ? .username : .emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(AppSpacing.xs)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if viewModel.isSignUp {
                        TextField("Confirm Email", text: $viewModel.confirmEmail)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(AppSpacing.xs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(viewModel.isSignUp ? .newPassword : .password)
                        .padding(AppSpacing.xs)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.coral)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(viewModel.isSignUp ? "Create Account" : "Sign In")
                                    .font(AppTypography.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.teal)
                    .disabled(viewModel.isLoading)

                    Button {
                        viewModel.isSignUp.toggle()
                        viewModel.errorMessage = nil
                        viewModel.firstName = ""
                        viewModel.lastName = ""
                        viewModel.confirmEmail = ""
                    } label: {
                        Text(viewModel.isSignUp
                             ? "Already have an account? Sign In"
                             : "Don't have an account? Sign Up")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .background(AppColors.background)
    }
}
