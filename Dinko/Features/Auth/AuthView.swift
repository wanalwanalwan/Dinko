import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        if viewModel.awaitingEmailVerification {
            EmailVerificationView(viewModel: viewModel)
        } else if viewModel.showForgotPassword {
            forgotPasswordForm
        } else {
            authForm
        }
    }

    // MARK: - Auth Form

    private var authForm: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                    .frame(height: 40)

                // Logo / Branding
                VStack(spacing: AppSpacing.xxs) {
                    CoachMascot(state: .idle, size: 72, animated: true)

                    Text("pkkl AI")
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

                    if !viewModel.isSignUp {
                        Button {
                            viewModel.showForgotPasswordForm()
                        } label: {
                            Text("Forgot password?")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(AppColors.textSecondary.opacity(0.3))
                            .frame(height: 1)
                        Text("or")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Rectangle()
                            .fill(AppColors.textSecondary.opacity(0.3))
                            .frame(height: 1)
                    }

                    // Sign in with Apple
                    Button {
                        Task { await viewModel.signInWithApple() }
                    } label: {
                        SignInWithAppleButton(
                            viewModel.isSignUp ? .signUp : .signIn
                        ) { _ in } onCompletion: { _ in }
                            .allowsHitTesting(false)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, AppSpacing.lg)

                // Legal links
                VStack(spacing: AppSpacing.xxxs) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    HStack(spacing: 4) {
                        Link("Privacy Policy", destination: URL(string: "https://github.com/wanalwanalwan/Dinko/blob/main/docs/privacy-policy.md")!)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.teal)

                        Text("and")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)

                        Link("Terms of Service", destination: URL(string: "https://github.com/wanalwanalwan/Dinko/blob/main/docs/terms-of-service.md")!)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
            }
        }
        .background(AppColors.background)
    }

    // MARK: - Forgot Password Form

    private var forgotPasswordForm: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            CoachMascot(state: .idle, size: 88, animated: true)

            if viewModel.passwordResetSent {
                // Success state
                VStack(spacing: AppSpacing.xs) {
                    Text("Check your email")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("We sent a password reset link to")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(viewModel.resetPasswordEmail)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.teal)
                }

                Text("Tap the link in the email to reset your password, then come back and sign in.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            } else {
                // Input state
                VStack(spacing: AppSpacing.xs) {
                    Text("Reset Password")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Enter your email and we'll send you a reset link.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: AppSpacing.sm) {
                    TextField("Email", text: $viewModel.resetPasswordEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
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
                        Task { await viewModel.sendPasswordReset() }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send Reset Link")
                                    .font(AppTypography.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.teal)
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            Button {
                viewModel.backToSignInFromReset()
            } label: {
                Text("Back to Sign In")
                    .font(AppTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.teal)
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
            Spacer()
        }
        .background(AppColors.background)
    }
}
