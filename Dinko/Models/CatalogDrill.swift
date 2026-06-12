import Foundation

struct CatalogDrill: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let skillCategory: String
    let difficultyTier: String
    let drillType: String
    let durationMinutes: Int
    let targetReps: Int
    let equipment: String
    let playerCount: Int
    let weekProgression: Int?
    let tags: [String]
}
