import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    var duprRange: String?
    var playFrequency: String?
    var trainingStyles: Set<String> = []
    var notificationsEnabled = false

    // MARK: - Starter Data

    func completeOnboarding(
        skillRepo: SkillRepository,
        ratingRepo: SkillRatingRepository,
        drillRepo: DrillRepository
    ) async throws {
        let starterSkills = generateStarterSkills()
        let baseRating = ratingForDUPR()

        for skill in starterSkills {
            try await skillRepo.save(skill)

            let rating = SkillRating(
                skillId: skill.id,
                rating: baseRating
            )
            try await ratingRepo.save(rating)
        }

        // Create first drill linked to the first skill
        if let firstSkill = starterSkills.first {
            let drill = generateFirstDrill(skillId: firstSkill.id)
            try await drillRepo.save(drill)
        }
    }

    func generateFirstDrill(skillId: UUID) -> Drill {
        switch duprRange {
        case "Beginner (2.0-2.5)":
            return Drill(
                skillId: skillId,
                name: "Dink Wall Drill",
                drillDescription: "Stand 7 feet from a wall and practice controlled dinks. Focus on soft hands and keeping the ball below the net line.",
                durationMinutes: 10,
                playerCount: 1,
                equipment: "Paddle, ball, wall",
                reason: "Builds the soft touch that separates beginners from intermediates.",
                priority: "high"
            )
        case "Intermediate (3.0-3.5)":
            return Drill(
                skillId: skillId,
                name: "Third Shot Drop Practice",
                drillDescription: "From the baseline, practice dropping the third shot into the kitchen. Aim for consistency over placement first.",
                durationMinutes: 10,
                playerCount: 1,
                equipment: "Paddle, balls, court",
                reason: "The third shot drop is the key to advancing from intermediate to advanced play.",
                priority: "high"
            )
        case "Advanced (4.0-4.5)":
            return Drill(
                skillId: skillId,
                name: "Transition Zone Volleys",
                drillDescription: "Practice hitting volleys while moving through the transition zone from baseline to kitchen line. Focus on split-stepping and shot selection.",
                durationMinutes: 10,
                playerCount: 2,
                equipment: "Paddle, balls, court",
                reason: "Mastering the transition zone separates 4.0 from 4.5+ players.",
                priority: "high"
            )
        default: // Pro (5.0+)
            return Drill(
                skillId: skillId,
                name: "Pattern Play: Shake & Bake",
                drillDescription: "Practice the shake and bake pattern: one player drives, partner poaches the volley. Alternate roles and work on timing.",
                durationMinutes: 10,
                playerCount: 2,
                equipment: "Paddle, balls, court",
                reason: "Advanced pattern play creates offensive pressure at the highest levels.",
                priority: "high"
            )
        }
    }

    // MARK: - Private Helpers

    private func ratingForDUPR() -> Int {
        switch duprRange {
        case "Beginner (2.0-2.5)": return 25
        case "Intermediate (3.0-3.5)": return 50
        case "Advanced (4.0-4.5)": return 70
        case "Pro (5.0+)": return 90
        default: return 30
        }
    }

    private func generateStarterSkills() -> [Skill] {
        SkillCategory.allCases.enumerated().map { index, category in
            Skill(
                name: category.displayName,
                category: category,
                description: "Track your \(category.displayName.lowercased()) skills",
                displayOrder: index,
                iconName: category.iconName
            )
        }
    }
}
