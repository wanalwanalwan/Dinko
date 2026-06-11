import Foundation

enum SessionType: String, CaseIterable, Codable, Identifiable {
    // Legacy cases (kept for backward compatibility with existing data)
    case game
    case drill

    // New mastery engine session types
    case learn
    case practice
    case apply
    case play
    case rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .game: return "Game"
        case .drill: return "Drill Session"
        case .learn: return "Learn"
        case .practice: return "Practice"
        case .apply: return "Apply"
        case .play: return "Play"
        case .rest: return "Rest"
        }
    }

    var iconName: String {
        switch self {
        case .game: return "figure.pickleball"
        case .drill: return "figure.run"
        case .learn: return "book.fill"
        case .practice: return "target"
        case .apply: return "flame.fill"
        case .play: return "figure.pickleball"
        case .rest: return "bed.double.fill"
        }
    }

    var description: String {
        switch self {
        case .game: return "Recreational or competitive play"
        case .drill: return "Focused practice on specific skills"
        case .learn: return "Understand the concept and technique"
        case .practice: return "Focused repetition to build muscle memory"
        case .apply: return "Test under pressure in game-like scenarios"
        case .play: return "Real game with a specific mission"
        case .rest: return "Recovery day"
        }
    }

    /// Short label for compact display (e.g. weekly strip)
    var shortLabel: String {
        switch self {
        case .game: return "Game"
        case .drill: return "Drill"
        case .learn: return "Learn"
        case .practice: return "Practice"
        case .apply: return "Apply"
        case .play: return "Play"
        case .rest: return "Rest"
        }
    }

    /// Whether this is a new mastery engine type (vs legacy)
    var isMasteryType: Bool {
        switch self {
        case .learn, .practice, .apply, .play, .rest: return true
        case .game, .drill: return false
        }
    }

    /// Session types available for manual logging (excludes mastery engine types)
    static var loggableTypes: [SessionType] {
        [.game, .drill]
    }

    /// Mastery engine session types (Learn -> Practice -> Apply -> Play cycle)
    static var masteryTypes: [SessionType] {
        [.learn, .practice, .apply, .play]
    }
}
