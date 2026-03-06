import Foundation

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

    private(set) var isAuthenticated = false
    private(set) var isCheckingSession = true
    private(set) var accessToken = ""
    private(set) var userId = ""

    private let authService = AuthService.shared

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
                        UserDefaults.standard.set(trimmedFirst, forKey: "dinko_first_name")
                    }
                    if !trimmedLast.isEmpty {
                        UserDefaults.standard.set(trimmedLast, forKey: "dinko_last_name")
                    }
                }
                isAuthenticated = true
            } else {
                // Email confirmation required — sign up succeeded but no session yet
                // Save names now so they persist after email confirmation + sign in
                let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedFirst.isEmpty {
                    UserDefaults.standard.set(trimmedFirst, forKey: "dinko_first_name")
                }
                if !trimmedLast.isEmpty {
                    UserDefaults.standard.set(trimmedLast, forKey: "dinko_last_name")
                }
                errorMessage = "Check your email to confirm your account, then sign in."
                isSignUp = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

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
}
