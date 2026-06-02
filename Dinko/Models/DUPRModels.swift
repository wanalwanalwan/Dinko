import Foundation

// MARK: - SSO Auth Result (from postMessage)

struct DUPRAuthResult: Codable {
    let userToken: String
    let refreshToken: String
    let id: String
    let duprId: String
    let stats: DUPRStats?
}

// MARK: - Stats / Ratings

struct DUPRStats: Codable {
    let singles: DUPRRatingInfo?
    let doubles: DUPRRatingInfo?
}

struct DUPRRatingInfo: Codable {
    let rating: Double?
    let provisional: Bool?
    let numberOfResults: Int?
}

// MARK: - Stored Profile

struct DUPRProfile: Codable, Equatable {
    let duprId: String
    let userId: String
    var displayName: String?
    var singlesRating: Double?
    var doublesRating: Double?
    var singlesProvisional: Bool
    var doublesProvisional: Bool
    let connectedAt: Date
    var lastRefreshed: Date

    init(
        duprId: String,
        userId: String,
        displayName: String? = nil,
        singlesRating: Double? = nil,
        doublesRating: Double? = nil,
        singlesProvisional: Bool = false,
        doublesProvisional: Bool = false,
        connectedAt: Date = Date(),
        lastRefreshed: Date = Date()
    ) {
        self.duprId = duprId
        self.userId = userId
        self.displayName = displayName
        self.singlesRating = singlesRating
        self.doublesRating = doublesRating
        self.singlesProvisional = singlesProvisional
        self.doublesProvisional = doublesProvisional
        self.connectedAt = connectedAt
        self.lastRefreshed = lastRefreshed
    }

    var formattedSingles: String {
        singlesRating.map { String(format: "%.2f", $0) } ?? "—"
    }

    var formattedDoubles: String {
        doublesRating.map { String(format: "%.2f", $0) } ?? "—"
    }
}

// MARK: - Rating Snapshot (local history)

struct DUPRRatingSnapshot: Codable, Identifiable {
    var id: UUID = UUID()
    let date: Date
    let singlesRating: Double?
    let doublesRating: Double?

    // Coding keys to persist id
    enum CodingKeys: String, CodingKey {
        case id, date, singlesRating, doublesRating
    }
}

// MARK: - Token Session

struct DUPRSession: Codable {
    let userToken: String
    let refreshToken: String
    let expiresAt: Date
}
