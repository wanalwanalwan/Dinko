import Foundation

struct ProgramTemplate: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var templateDescription: String
    var author: String
    var difficulty: ProgramDifficulty
    var totalWeeks: Int
    var sessionsPerWeek: Int
    var skillFocus: String
    var isPremium: Bool
    var tags: [String]
    var sessions: [ProgramTemplateSession]
}

struct ProgramTemplateSession: Identifiable, Hashable, Codable {
    let id: String
    var weekNumber: Int
    var sessionNumber: Int
    var title: String
    var focus: String
    var estimatedMinutes: Int
    var drills: [ProgramTemplateDrill]
}

struct ProgramTemplateDrill: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var drillDescription: String
    var durationMinutes: Int
    var targetReps: Int
    var equipment: String
    var playerCount: Int
}

enum ProgramDifficulty: String, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
}
