import Foundation
import AuthenticationServices
import CryptoKit

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var confirmEmail = ""
    var password = ""
    var firstName = ""
    var lastName = ""
    var isSignUp = false
    var isLoading = false
    var errorMessage: String?

    // Email verification state
    private(set) var awaitingEmailVerification = false
    private(set) var verificationEmail = ""
    var resendCooldown = 0
    private var resendTimer: Timer?

    // Forgot password state
    var showForgotPassword = false
    var resetPasswordEmail = ""
    private(set) var passwordResetSent = false

    private(set) var isAuthenticated = false
    private(set) var isCheckingSession = true
    private(set) var accessToken = ""
    private(set) var userId = ""

    // Account deletion
    var showDeleteConfirmation = false
    var isDeletingAccount = false

    private let authService = AuthService.shared
    private let agentService = AgentService()

    /// Try to restore a saved session on launch
    func restoreSession() async {
        defer { isCheckingSession = false }
        guard let saved = authService.loadSavedSession() else { return }

        // Try refreshing the token (access tokens expire after 1 hour)
        do {
            let response = try await authService.refreshSession(refreshToken: saved.refreshToken)
            guard response.hasSession else { return }
            authService.saveSession(response)
            accessToken = response.accessToken ?? ""
            userId = response.user.id
            isAuthenticated = true
        } catch {
            // Refresh failed — token expired or revoked, user needs to sign in again
            authService.clearSession()
        }
    }

    func submit() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedPassword = password

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Email and password are required."
            return
        }

        guard Self.isValidEmail(trimmedEmail) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        if isSignUp {
            guard !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "First and last name are required."
                return
            }

            let trimmedConfirm = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard trimmedEmail == trimmedConfirm else {
                errorMessage = "Email addresses don't match."
                return
            }
        }

        guard trimmedPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response: AuthService.AuthResponse
            if isSignUp {
                response = try await authService.signUp(email: trimmedEmail, password: trimmedPassword)
            } else {
                response = try await authService.signIn(email: trimmedEmail, password: trimmedPassword)
            }

            if response.hasSession {
                authService.saveSession(response)
                accessToken = response.accessToken ?? ""
                userId = response.user.id
                if isSignUp {
                    let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedFirst.isEmpty {
                        UserDefaults.standard.set(trimmedFirst, forKey: "pkkl_first_name")
                    }
                    if !trimmedLast.isEmpty {
                        UserDefaults.standard.set(trimmedLast, forKey: "pkkl_last_name")
                    }
                }
                isAuthenticated = true
            } else {
                // Email confirmation required — sign up succeeded but no session yet
                // Save names now so they persist after email confirmation + sign in
                let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedFirst.isEmpty {
                    UserDefaults.standard.set(trimmedFirst, forKey: "pkkl_first_name")
                }
                if !trimmedLast.isEmpty {
                    UserDefaults.standard.set(trimmedLast, forKey: "pkkl_last_name")
                }
                verificationEmail = trimmedEmail
                awaitingEmailVerification = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Email Verification

    func resendVerificationEmail() async {
        guard !verificationEmail.isEmpty, resendCooldown == 0 else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await authService.resendVerification(email: verificationEmail)
            startResendCooldown()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func backToSignIn() {
        awaitingEmailVerification = false
        verificationEmail = ""
        isSignUp = false
        password = ""
        errorMessage = nil
        resendTimer?.invalidate()
        resendCooldown = 0
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.resendCooldown -= 1
                if self.resendCooldown <= 0 {
                    timer.invalidate()
                    self.resendCooldown = 0
                }
            }
        }
    }

    // MARK: - Forgot Password

    func sendPasswordReset() async {
        let trimmedEmail = resetPasswordEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }

        guard Self.isValidEmail(trimmedEmail) else {
            errorMessage = "Please enter a valid email address."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.resetPassword(email: trimmedEmail)
            passwordResetSent = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func showForgotPasswordForm() {
        showForgotPassword = true
        resetPasswordEmail = email // Pre-fill with current email
        passwordResetSent = false
        errorMessage = nil
    }

    func backToSignInFromReset() {
        showForgotPassword = false
        resetPasswordEmail = ""
        passwordResetSent = false
        errorMessage = nil
    }

    // MARK: - Apple Sign-In

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil

        do {
            let coordinator = AppleSignInCoordinator()
            let result = try await coordinator.signIn()

            let response = try await authService.signInWithApple(
                idToken: result.idToken,
                nonce: result.rawNonce
            )

            if response.hasSession {
                authService.saveSession(response)
                accessToken = response.accessToken ?? ""
                userId = response.user.id

                // Apple only provides name on first authorization
                if let givenName = result.fullName?.givenName, !givenName.isEmpty {
                    UserDefaults.standard.set(givenName, forKey: "pkkl_first_name")
                }
                if let familyName = result.fullName?.familyName, !familyName.isEmpty {
                    UserDefaults.standard.set(familyName, forKey: "pkkl_last_name")
                }

                isAuthenticated = true
            }
        } catch let error as AppleSignInError where error == .canceled {
            // User dismissed the Apple Sign-In sheet — do nothing
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Account Deletion

    func deleteAccount() async {
        isDeletingAccount = true

        do {
            try await agentService.deleteAccount(authToken: accessToken)
        } catch {
            isDeletingAccount = false
            errorMessage = "Failed to delete account. Please check your connection and try again."
            return
        }

        // Server confirmed deletion — clear all local data
        authService.clearSession()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "pkkl_weekly_goal")
        UserDefaults.standard.removeObject(forKey: "pkkl_drill_preferences")

        accessToken = ""
        userId = ""
        isDeletingAccount = false
        isAuthenticated = false
        email = ""
        password = ""
    }

    // MARK: - Sign Out

    func signOut() async {
        await authService.signOut(accessToken: accessToken)
        authService.clearSession()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        accessToken = ""
        userId = ""
        isAuthenticated = false
        email = ""
        password = ""
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
