import Foundation

enum SessionType: String, CaseIterable, Codable, Identifiable {
    case game
    case drill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .game: return "Game"
        case .drill: return "Drill Session"
        }
    }

    var iconName: String {
        switch self {
        case .game: return "figure.pickleball"
        case .drill: return "figure.run"
        }
    }

    var description: String {
        switch self {
        case .game: return "Recreational or competitive play"
        case .drill: return "Focused practice on specific skills"
        }
    }
}
