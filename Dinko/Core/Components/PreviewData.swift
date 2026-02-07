import Foundation

enum PreviewData {
    static let serveSkill = SkillPreview(
        name: "Serve",
        iconName: "figure.pickleball",
        category: "Offense",
        rating: 75,
        previousRating: 70,
        totalCheckers: 4,
        completedCheckers: 2,
        ratingHistory: [60, 63, 65, 68, 70, 72, 75]
    )

    static let dinkSkill = SkillPreview(
        name: "Dink",
        iconName: "figure.pickleball",
        category: "Strategy",
        rating: 85,
        previousRating: 80,
        totalCheckers: 5,
        completedCheckers: 4,
        ratingHistory: [70, 72, 75, 78, 80, 83, 85]
    )

    static let volleySkill = SkillPreview(
        name: "Volley",
        iconName: "figure.pickleball",
        category: "Offense",
        rating: 60,
        previousRating: 60,
        totalCheckers: 3,
        completedCheckers: 1,
        ratingHistory: [55, 57, 58, 59, 60, 60, 60]
    )

    static let thirdShotSkill = SkillPreview(
        name: "Third Shot Drop",
        iconName: "figure.pickleball",
        category: "Strategy",
        rating: 55,
        previousRating: 50,
        totalCheckers: 4,
        completedCheckers: 1,
        ratingHistory: [40, 42, 45, 48, 50, 52, 55]
    )

    static let footworkSkill = SkillPreview(
        name: "Footwork",
        iconName: "figure.run",
        category: "Movement",
        rating: 70,
        previousRating: 68,
        totalCheckers: 3,
        completedCheckers: 2,
        ratingHistory: [58, 60, 63, 65, 67, 68, 70]
    )

    static let strategySkill = SkillPreview(
        name: "Court Strategy",
        iconName: "brain.head.profile",
        category: "Strategy",
        rating: 85,
        previousRating: 80,
        totalCheckers: 5,
        completedCheckers: 4,
        ratingHistory: [65, 70, 73, 76, 78, 80, 85]
    )

    static let allSkills = [serveSkill, dinkSkill, volleySkill, thirdShotSkill, footworkSkill, strategySkill]

    static let serveCheckers = [
        CheckerPreview(name: "Consistent deep serve", isCompleted: true),
        CheckerPreview(name: "Spin serve", isCompleted: false),
        CheckerPreview(name: "Placement accuracy", isCompleted: true),
        CheckerPreview(name: "Power serve", isCompleted: false),
    ]

    static let achievements = [
        AchievementPreview(name: "Getting Started", iconName: "star.fill", isUnlocked: true, color: .achievementPink),
        AchievementPreview(name: "Solid Player", iconName: "shield.fill", isUnlocked: true, color: .achievementBlue),
        AchievementPreview(name: "Advanced", iconName: "trophy.fill", isUnlocked: false, color: .achievementYellow),
    ]
}

struct SkillPreview: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let category: String
    let rating: Int
    let previousRating: Int
    let totalCheckers: Int
    let completedCheckers: Int
    let ratingHistory: [Int]

    var trendChange: Int { rating - previousRating }
    var checkerProgress: Double {
        totalCheckers > 0 ? Double(completedCheckers) / Double(totalCheckers) : 0
    }
}

struct CheckerPreview: Identifiable {
    let id = UUID()
    let name: String
    let isCompleted: Bool
}

enum AchievementColor {
    case achievementPink, achievementBlue, achievementYellow
}

struct AchievementPreview: Identifiable {
    let id = UUID()
    let name: String
    let iconName: String
    let isUnlocked: Bool
    let color: AchievementColor
}
