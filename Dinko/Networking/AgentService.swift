import Foundation

/// Calls the dinkit-agent Supabase Edge Function
final class AgentService {
    private let session = URLSession.shared

    struct LogSessionResponse: Codable {
        let sessionId: String?
        let extraction: ExtractionData?
        let coachInsight: String?
        let skillUpdates: [SkillUpdate]?
        let drillRecommendations: [DrillRecommendation]?
        let roadmapUpdates: RoadmapUpdates?
        let subskillSuggestions: [SubskillSuggestion]?
        let skillSuggestions: [SkillCreationSuggestion]?
        let saturatedSkills: [SaturatedSkillInfo]?
        let chatResponse: String?
        let clarification: ClarificationResponseData?

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case extraction
            case coachInsight = "coach_insight"
            case skillUpdates = "skill_updates"
            case drillRecommendations = "drill_recommendations"
            case roadmapUpdates = "roadmap_updates"
            case subskillSuggestions = "subskill_suggestions"
            case skillSuggestions = "skill_suggestions"
            case saturatedSkills = "saturated_skills"
            case chatResponse = "chat_response"
            case clarification
        }
    }

    struct ClarificationResponseData: Codable {
        let question: String
        let options: [ClarificationOptionData]
        let originalNote: String?

        enum CodingKeys: String, CodingKey {
            case question, options
            case originalNote = "original_note"
        }
    }

    struct ClarificationOptionData: Codable {
        let id: String
        let label: String
        let action: String
        let payload: [String: String]?
    }

    struct SaturatedSkillInfo: Codable {
        let skillName: String
        let pendingCount: Int

        enum CodingKeys: String, CodingKey {
            case skillName = "skill_name"
            case pendingCount = "pending_count"
        }
    }

    struct ConfirmResponse: Codable {
        let confirmed: Bool
        let sessionId: String

        enum CodingKeys: String, CodingKey {
            case confirmed
            case sessionId = "session_id"
        }
    }

    struct ErrorResponse: Codable {
        let error: String?
        let msg: String?

        var message: String {
            error ?? msg ?? "Unknown error"
        }
    }

    struct SkillSnapshotPayload: Codable {
        let id: String
        let name: String
        let category: String
        let currentRating: Int
        let parentSkillId: String?
        let subskills: [SubskillPayload]
        let pendingDrillCount: Int

        enum CodingKeys: String, CodingKey {
            case id, name, category
            case currentRating = "current_rating"
            case parentSkillId = "parent_skill_id"
            case subskills
            case pendingDrillCount = "pending_drill_count"
        }
    }

    struct SubskillPayload: Codable {
        let id: String
        let name: String
        let currentRating: Int

        enum CodingKeys: String, CodingKey {
            case id, name
            case currentRating = "current_rating"
        }
    }

    /// Log a session note and get AI analysis preview
    func logSession(
        note: String,
        skills: [SkillSnapshotPayload],
        authToken: String,
        clarificationAction: [String: Any]? = nil
    ) async throws -> LogSessionResponse {
        var body: [String: Any] = [
            "action": "log_session",
            "note": note,
            "skills": skills.map { skill in
                var dict: [String: Any] = [
                    "id": skill.id,
                    "name": skill.name,
                    "category": skill.category,
                    "current_rating": skill.currentRating,
                    "pending_drill_count": skill.pendingDrillCount,
                    "subskills": skill.subskills.map { sub in
                        [
                            "id": sub.id,
                            "name": sub.name,
                            "current_rating": sub.currentRating,
                        ] as [String: Any]
                    },
                ]
                if let parentId = skill.parentSkillId {
                    dict["parent_skill_id"] = parentId
                }
                return dict
            },
        ]

        if let clarificationAction {
            body["clarification_action"] = clarificationAction
        }

        return try await post(body: body, authToken: authToken)
    }

    /// Confirm a session to apply changes to DB
    func confirmSession(
        sessionId: String,
        authToken: String
    ) async throws -> ConfirmResponse {
        let body: [String: Any] = [
            "action": "confirm_session",
            "session_id": sessionId,
        ]

        return try await post(body: body, authToken: authToken)
    }

    struct DeleteAccountResponse: Codable {
        let deleted: Bool
    }

    /// Delete the user's account and all associated data
    func deleteAccount(authToken: String) async throws {
        let body: [String: Any] = [
            "action": "delete_account",
        ]

        let _: DeleteAccountResponse = try await post(body: body, authToken: authToken)
    }

    // MARK: - Private

    private func post<T: Codable>(body: [String: Any], authToken: String) async throws -> T {
        // Proactively refresh if the token is expired or about to expire
        let tokenToUse: String
        if AuthService.shared.isTokenExpired(buffer: 60) {
            if let freshToken = await refreshToken(), !freshToken.isEmpty {
                tokenToUse = freshToken
            } else {
                // Refresh failed — session is dead, clear it and force re-auth
                AuthService.shared.clearSession()
                NotificationCenter.default.post(name: .authSessionExpired, object: nil)
                throw AgentError.server("Your session has expired. Please sign in again.")
            }
        } else {
            tokenToUse = authToken
        }

        // First attempt with a valid (or freshly refreshed) token
        let result: (Data, HTTPURLResponse) = try await executeRequest(body: body, authToken: tokenToUse)

        // If still 401, try refreshing once more as a fallback
        if result.1.statusCode == 401 {
            if let freshToken = await refreshToken(), !freshToken.isEmpty {
                let retry: (Data, HTTPURLResponse) = try await executeRequest(body: body, authToken: freshToken)
                // If retry also returns 401, the session is dead
                if retry.1.statusCode == 401 {
                    AuthService.shared.clearSession()
                    NotificationCenter.default.post(name: .authSessionExpired, object: nil)
                    throw AgentError.server("Your session has expired. Please sign in again.")
                }
                return try decodeResponse(data: retry.0, statusCode: retry.1.statusCode)
            }

            // Refresh failed — session is dead, clear it and force re-auth
            AuthService.shared.clearSession()
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            throw AgentError.server("Your session has expired. Please sign in again.")
        }

        return try decodeResponse(data: result.0, statusCode: result.1.statusCode)
    }

    private func executeRequest(body: [String: Any], authToken: String) async throws -> (Data, HTTPURLResponse) {
        let trimmedToken = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            throw AgentError.server("Missing access token. Please sign in again.")
        }

        guard let url = URL(string: SupabaseConfig.agentFunctionURL) else {
            throw AgentError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw AgentError.offline
            case .timedOut:
                throw AgentError.server("Request timed out. The AI coach may be busy — please try again.")
            default:
                throw AgentError.server("Network error: \(urlError.localizedDescription)")
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        return (data, httpResponse)
    }

    private func decodeResponse<T: Codable>(data: Data, statusCode: Int) throws -> T {
        if statusCode != 200 {
            // 502/503/504 are gateway errors — edge function timed out or crashed
            if (502...504).contains(statusCode) {
                throw AgentError.server("The AI coach is temporarily unavailable. Please try again in a moment.")
            }

            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data),
               (errorResponse.error != nil || errorResponse.msg != nil) {
                throw AgentError.server(errorResponse.message)
            }

            // Don't show raw HTML to the user
            if let body = responseBodyString(data), !body.isEmpty, !body.contains("<!DOCTYPE") && !body.contains("<html") {
                throw AgentError.server("HTTP \(statusCode): \(body)")
            }

            throw AgentError.server("Something went wrong (HTTP \(statusCode)). Please try again.")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func responseBodyString(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 600 {
            let idx = trimmed.index(trimmed.startIndex, offsetBy: 600)
            return String(trimmed[..<idx]) + "…"
        }
        return trimmed
    }

    private func refreshToken() async -> String? {
        return await AuthService.tokenRefresher.refresh()
    }
}

enum AgentError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .invalidResponse: "Invalid response from server"
        case .server(let message): message
        case .offline: "You're offline. Please check your connection and try again."
        }
    }
}

extension Notification.Name {
    static let authSessionExpired = Notification.Name("authSessionExpired")
}
