import Foundation
import Observation

@MainActor
@Observable
final class DUPRService {
    static let shared = DUPRService()

    private(set) var profile: DUPRProfile?
    private(set) var ratingHistory: [DUPRRatingSnapshot] = []
    private(set) var isRefreshing = false

    private let profileKey    = "dupr_profile"
    private let historyKey    = "dupr_rating_history"
    private let userTokenKey  = "dupr_user_token"
    private let refreshTokenKey = "dupr_refresh_token"

    var isConnected: Bool { profile != nil }

    var singlesRatingDelta: Double? {
        guard let current = profile?.singlesRating,
              let first = ratingHistory.first?.singlesRating else { return nil }
        return current - first
    }

    var doublesRatingDelta: Double? {
        guard let current = profile?.doublesRating,
              let first = ratingHistory.first?.doublesRating else { return nil }
        return current - first
    }

    private init() {
        loadFromDefaults()
    }

    // MARK: - Connect from SSO

    func connectWithAuthResult(_ result: DUPRAuthResult) {
        let newProfile = DUPRProfile(
            duprId: result.duprId,
            userId: result.id,
            singlesRating: result.stats?.singles?.rating,
            doublesRating: result.stats?.doubles?.rating,
            singlesProvisional: result.stats?.singles?.provisional ?? false,
            doublesProvisional: result.stats?.doubles?.provisional ?? false
        )
        profile = newProfile
        saveSession(userToken: result.userToken, refreshToken: result.refreshToken)
        saveProfile(newProfile)

        let snapshot = DUPRRatingSnapshot(
            date: Date(),
            singlesRating: result.stats?.singles?.rating,
            doublesRating: result.stats?.doubles?.rating
        )
        appendSnapshot(snapshot)
    }

    // MARK: - Refresh Rating

    func refreshRating() async {
        guard !isRefreshing,
              let token = UserDefaults.standard.string(forKey: userTokenKey),
              var updatedProfile = profile else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fetched = try await fetchBasicInfo(userToken: token)
            updatedProfile.singlesRating = fetched.singlesRating
            updatedProfile.doublesRating = fetched.doublesRating
            updatedProfile.singlesProvisional = fetched.singlesProvisional
            updatedProfile.doublesProvisional = fetched.doublesProvisional
            updatedProfile.displayName = fetched.displayName ?? updatedProfile.displayName
            updatedProfile.lastRefreshed = Date()
            profile = updatedProfile
            saveProfile(updatedProfile)

            let last = ratingHistory.last
            let singlesChanged = last?.singlesRating != fetched.singlesRating
            let doublesChanged = last?.doublesRating != fetched.doublesRating
            if singlesChanged || doublesChanged || ratingHistory.isEmpty {
                appendSnapshot(DUPRRatingSnapshot(
                    date: Date(),
                    singlesRating: fetched.singlesRating,
                    doublesRating: fetched.doublesRating
                ))
            }
        } catch {
            // Silently fail — stale data is fine
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        profile = nil
        ratingHistory = []
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: historyKey)
        UserDefaults.standard.removeObject(forKey: userTokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
    }

    // MARK: - API: Basic User Info

    private struct BasicInfoResponse: Codable {
        let status: String?
        let result: BasicInfoResult?

        struct BasicInfoResult: Codable {
            let duprId: String?
            let displayName: String?
            let fullName: String?
            let ratings: BasicInfoRatings?

            enum CodingKeys: String, CodingKey {
                case duprId = "dupr_id"
                case displayName = "display_name"
                case fullName = "full_name"
                case ratings
            }
        }

        struct BasicInfoRatings: Codable {
            let singles: Double?
            let doubles: Double?
            let singlesProvisional: Bool?
            let doublesProvisional: Bool?

            enum CodingKeys: String, CodingKey {
                case singles, doubles
                case singlesProvisional = "singles_provisional"
                case doublesProvisional = "doubles_provisional"
            }
        }
    }

    private func fetchBasicInfo(userToken: String) async throws -> DUPRProfile {
        // Try refreshing the token if needed, then hit the public API
        var token = userToken
        if let refreshed = try? await refreshTokenIfNeeded() {
            token = refreshed
        }

        let url = URL(string: "\(DUPRConfig.apiBaseURL)/api/v1.0/user/basic")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            // Token expired — try refresh
            if let refreshed = try? await refreshTokenIfNeeded() {
                var retryRequest = request
                retryRequest.setValue("Bearer \(refreshed)", forHTTPHeaderField: "Authorization")
                let (retryData, _) = try await URLSession.shared.data(for: retryRequest)
                return try parseBasicInfo(retryData)
            }
        }

        return try parseBasicInfo(data)
    }

    private func parseBasicInfo(_ data: Data) throws -> DUPRProfile {
        let decoded = try JSONDecoder().decode(BasicInfoResponse.self, from: data)
        let result = decoded.result
        return DUPRProfile(
            duprId: result?.duprId ?? profile?.duprId ?? "",
            userId: profile?.userId ?? "",
            displayName: result?.fullName ?? result?.displayName,
            singlesRating: result?.ratings?.singles,
            doublesRating: result?.ratings?.doubles,
            singlesProvisional: result?.ratings?.singlesProvisional ?? false,
            doublesProvisional: result?.ratings?.doublesProvisional ?? false,
            connectedAt: profile?.connectedAt ?? Date()
        )
    }

    // MARK: - Token Refresh

    private struct TokenRefreshResponse: Codable {
        let status: String?
        let result: TokenResult?
        struct TokenResult: Codable {
            let accessToken: String?
            let refreshToken: String?
        }
    }

    private func refreshTokenIfNeeded() async throws -> String? {
        guard let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) else { return nil }

        let url = URL(string: "\(DUPRConfig.apiBaseURL)/api/v1.0/auth/refresh")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["refreshToken": refreshToken])

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        if let newAccess = decoded.result?.accessToken,
           let newRefresh = decoded.result?.refreshToken {
            UserDefaults.standard.set(newAccess, forKey: userTokenKey)
            UserDefaults.standard.set(newRefresh, forKey: refreshTokenKey)
            return newAccess
        }
        return nil
    }

    // MARK: - Persistence

    private func saveSession(userToken: String, refreshToken: String) {
        UserDefaults.standard.set(userToken, forKey: userTokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
    }

    private func saveProfile(_ profile: DUPRProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    private func appendSnapshot(_ snapshot: DUPRRatingSnapshot) {
        ratingHistory.append(snapshot)
        ratingHistory.sort { $0.date < $1.date }
        // Keep last 90 snapshots max
        if ratingHistory.count > 90 {
            ratingHistory = Array(ratingHistory.suffix(90))
        }
        if let data = try? JSONEncoder().encode(ratingHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func loadFromDefaults() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(DUPRProfile.self, from: data) {
            profile = saved
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([DUPRRatingSnapshot].self, from: data) {
            ratingHistory = saved
        }
    }
}
