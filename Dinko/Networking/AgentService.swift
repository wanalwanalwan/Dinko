import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Calls the dinkit-agent Supabase Edge Function
final class AgentService {
    private let session = URLSession.shared

    struct LogSessionResponse: Codable {
        let sessionId: String
        let extraction: ExtractionData
        let skillUpdates: [SkillUpdate]
        let drillRecommendations: [DrillRecommendation]
        let roadmapUpdates: RoadmapUpdates?
        let subskillSuggestions: [SubskillSuggestion]?
        let skillSuggestions: [SkillCreationSuggestion]?

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case extraction
            case skillUpdates = "skill_updates"
            case drillRecommendations = "drill_recommendations"
            case roadmapUpdates = "roadmap_updates"
            case subskillSuggestions = "subskill_suggestions"
            case skillSuggestions = "skill_suggestions"
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
        let error: String
    }

    struct SkillSnapshotPayload: Codable {
        let id: String
        let name: String
        let category: String
        let currentRating: Int
        let parentSkillId: String?
        let subskills: [SubskillPayload]

        enum CodingKeys: String, CodingKey {
            case id, name, category
            case currentRating = "current_rating"
            case parentSkillId = "parent_skill_id"
            case subskills
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
        authToken: String
    ) async throws -> LogSessionResponse {
        let body: [String: Any] = [
            "action": "log_session",
            "note": note,
            "skills": skills.map { skill in
                var dict: [String: Any] = [
                    "id": skill.id,
                    "name": skill.name,
                    "category": skill.category,
                    "current_rating": skill.currentRating,
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

        return try await post(body: body, authToken: authToken)
    }

    /// Confirm a session to apply changes to DB
    func confirmSession(
        sessionId: String,
        roadmapUpdates: RoadmapUpdates?,
        authToken: String
    ) async throws -> ConfirmResponse {
        var body: [String: Any] = [
            "action": "confirm_session",
            "session_id": sessionId,
        ]

        if let roadmap = roadmapUpdates {
            let encoder = JSONEncoder()
            let roadmapData = try encoder.encode(roadmap)
            let roadmapDict = try JSONSerialization.jsonObject(with: roadmapData)
            body["roadmap_updates"] = roadmapDict
        }

        return try await post(body: body, authToken: authToken)
    }

    // MARK: - Private

    private func post<T: Codable>(body: [String: Any], authToken: String) async throws -> T {
        // First attempt
        let result: (Data, HTTPURLResponse) = try await executeRequest(body: body, authToken: authToken)

        // If 401, try refreshing the token and retry once
        if result.1.statusCode == 401 {
            if let freshToken = await refreshToken(), !freshToken.isEmpty {
                let retry: (Data, HTTPURLResponse) = try await executeRequest(body: body, authToken: freshToken)
                return try decodeResponse(data: retry.0, statusCode: retry.1.statusCode)
            }
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

#if DEBUG
        debugBreakBeforeSendingAuthHeader(token: trimmedToken)
#endif

        request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentError.invalidResponse
        }

        return (data, httpResponse)
    }

    private func decodeResponse<T: Codable>(data: Data, statusCode: Int) throws -> T {
        if statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AgentError.server("HTTP \(statusCode): \(errorResponse.error)")
            }

            if let body = responseBodyString(data), !body.isEmpty {
                throw AgentError.server("HTTP \(statusCode): \(body)")
            }

            throw AgentError.server("HTTP \(statusCode): Request failed")
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

#if DEBUG
    /// Opt-in programmatic "breakpoint" so you can inspect the token in Xcode.
    /// Enable by adding the environment variable `DINKO_AGENT_BREAK=1` to your run scheme.
    private func debugBreakBeforeSendingAuthHeader(token: String) {
        guard ProcessInfo.processInfo.environment["DINKO_AGENT_BREAK"] == "1" else { return }
        // Set a breakpoint on the line below, or let SIGTRAP pause execution.
        raise(SIGTRAP)
    }
#endif

    private func refreshToken() async -> String? {
        let authService = AuthService.shared
        guard let saved = authService.loadSavedSession() else { return nil }
        do {
            let response = try await authService.refreshSession(refreshToken: saved.refreshToken)
            if response.hasSession {
                authService.saveSession(response)
                return response.accessToken
            }
        } catch {}
        return nil
    }
}

enum AgentError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid server URL"
        case .invalidResponse: "Invalid response from server"
        case .server(let message): message
        }
    }
}
