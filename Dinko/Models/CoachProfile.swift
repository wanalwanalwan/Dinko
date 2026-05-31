import Foundation

struct CoachProfile: Identifiable, Hashable, Codable {
    let id: UUID
    let displayName: String
    let coachBio: String?
    let coachSpecialties: [String]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case coachBio = "coach_bio"
        case coachSpecialties = "coach_specialties"
    }

    var initials: String {
        displayName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map { String($0) } }
            .joined()
            .uppercased()
    }

    var firstName: String {
        String(displayName.split(separator: " ").first ?? Substring(displayName))
    }
}
