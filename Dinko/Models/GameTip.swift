import Foundation

struct GameTip: Codable, Identifiable {
    let id: String
    let title: String
    let tip: String
    let situation: String
}

struct SkillCoachingResponse: Codable {
    let gameTips: [GameTip]
    let drills: [DrillRecommendation]

    enum CodingKeys: String, CodingKey {
        case gameTips = "game_tips"
        case drills
    }
}
