import AuthenticationServices
import CryptoKit
import Foundation

struct AppleSignInResult {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

enum AppleSignInError: LocalizedError, Equatable {
    case canceled
    case missingToken

    var errorDescription: String? {
        switch self {
        case .canceled: "Sign in was canceled."
        case .missingToken: "Unable to retrieve identity token from Apple."
        }
    }
}

final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var rawNonce: String = ""

    func signIn() async throws -> AppleSignInResult {
        rawNonce = Self.randomNonceString()
        let hashedNonce = Self.sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AppleSignInError.missingToken)
            continuation = nil
            return
        }

        let result = AppleSignInResult(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: credential.fullName,
            email: credential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            continuation?.resume(throwing: AppleSignInError.canceled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    // MARK: - Nonce Utilities

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(result == errSecSuccess, "Failed to generate random bytes")

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
