import Foundation
import Security

/// Lightweight Supabase Auth client using the REST API directly.
final class AuthService {
    static let shared = AuthService()

    private let session = URLSession.shared
    private let baseURL = "\(SupabaseConfig.url)/auth/v1"

    private let keychainAccountAccess = "dinkit_access_token"
    private let keychainAccountRefresh = "dinkit_refresh_token"
    private let userDefaultsUserKey = "dinkit_user_json"

    // MARK: - Response Types

    struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Int
        let user: AuthUser

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case user
        }
    }

    struct AuthUser: Codable {
        let id: String
        let email: String?
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case email
            case createdAt = "created_at"
        }
    }

    struct AuthError: Codable {
        let error: String?
        let errorDescription: String?
        let msg: String?

        enum CodingKeys: String, CodingKey {
            case error
            case errorDescription = "error_description"
            case msg
        }

        var message: String {
            errorDescription ?? msg ?? error ?? "Unknown auth error"
        }
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String) async throws -> AuthResponse {
        let body: [String: String] = ["email": email, "password": password]
        return try await post(path: "/signup", body: body)
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async throws -> AuthResponse {
        let body: [String: String] = ["email": email, "password": password]
        return try await post(path: "/token?grant_type=password", body: body)
    }

    // MARK: - Refresh Token

    func refreshSession(refreshToken: String) async throws -> AuthResponse {
        let body: [String: String] = ["refresh_token": refreshToken]
        return try await post(path: "/token?grant_type=refresh_token", body: body)
    }

    // MARK: - Sign Out

    func signOut(accessToken: String) async {
        guard let url = URL(string: "\(baseURL)/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        _ = try? await session.data(for: request)
    }

    // MARK: - Session Persistence (Keychain for tokens, UserDefaults for user info)

    func saveSession(_ response: AuthResponse) {
        KeychainHelper.save(key: keychainAccountAccess, value: response.accessToken)
        KeychainHelper.save(key: keychainAccountRefresh, value: response.refreshToken)
        if let data = try? JSONEncoder().encode(response.user) {
            UserDefaults.standard.set(data, forKey: userDefaultsUserKey)
        }
    }

    func loadSavedSession() -> (accessToken: String, refreshToken: String, user: AuthUser)? {
        guard let access = KeychainHelper.load(key: keychainAccountAccess),
              let refresh = KeychainHelper.load(key: keychainAccountRefresh),
              let userData = UserDefaults.standard.data(forKey: userDefaultsUserKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: userData)
        else { return nil }
        return (access, refresh, user)
    }

    func clearSession() {
        KeychainHelper.delete(key: keychainAccountAccess)
        KeychainHelper.delete(key: keychainAccountRefresh)
        UserDefaults.standard.removeObject(forKey: userDefaultsUserKey)
    }

    // MARK: - Private

    private func post<T: Codable>(path: String, body: some Encodable) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw AuthServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let authError = try? JSONDecoder().decode(AuthError.self, from: data) {
                throw AuthServiceError.server(authError.message)
            }
            throw AuthServiceError.server("Auth failed with status \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum AuthServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid auth URL"
        case .invalidResponse: "Invalid response"
        case .server(let msg): msg
        }
    }
}

// MARK: - Minimal Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
