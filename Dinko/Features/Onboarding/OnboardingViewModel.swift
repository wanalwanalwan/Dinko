import Foundation

@MainActor
@Observable
final class OnboardingViewModel {
    var duprRange: String?
    var trainingDaysPerWeek: Int?
    var drillPreferences: Set<String> = []

    func completeOnboarding(
        skillRepo: SkillRepository,
        ratingRepo: SkillRatingRepository
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

        persistPreferences()
    }

    // MARK: - Private Helpers

    private func persistPreferences() {
        if let days = trainingDaysPerWeek {
            UserDefaults.standard.set(days, forKey: "dinko_weekly_goal")
        }
        if !drillPreferences.isEmpty {
            UserDefaults.standard.set(Array(drillPreferences), forKey: "dinko_drill_preferences")
        }
    }

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
