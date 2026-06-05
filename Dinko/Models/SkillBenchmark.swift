import Foundation

// MARK: - DUPR Range

enum DUPRRange: String, CaseIterable {
    case beginner_2_0_3_0
    case intermediate_3_0_3_5
    case intermediate_3_5_4_0
    case advanced_4_0_4_5
    case advanced_4_5_5_0
    case pro_5_0_plus

    /// Parse from onboarding profile strings like "Beginner (2.0-3.0)"
    static func from(profileString: String?) -> DUPRRange? {
        guard let str = profileString?.lowercased() else { return nil }
        if str.contains("2.0") && str.contains("3.0") { return .beginner_2_0_3_0 }
        if str.contains("3.0") && str.contains("3.5") { return .intermediate_3_0_3_5 }
        if str.contains("3.5") && str.contains("4.0") { return .intermediate_3_5_4_0 }
        if str.contains("4.0") && str.contains("4.5") { return .advanced_4_0_4_5 }
        if str.contains("4.5") && str.contains("5.0") { return .advanced_4_5_5_0 }
        if str.contains("5.0") || str.contains("pro")  { return .pro_5_0_plus }
        return nil
    }

    /// Parse from an actual numeric DUPR rating
    static func from(numericRating: Double) -> DUPRRange {
        switch numericRating {
        case ..<3.0:  return .beginner_2_0_3_0
        case 3.0..<3.5: return .intermediate_3_0_3_5
        case 3.5..<4.0: return .intermediate_3_5_4_0
        case 4.0..<4.5: return .advanced_4_0_4_5
        case 4.5..<5.0: return .advanced_4_5_5_0
        default:         return .pro_5_0_plus
        }
    }

    var displayName: String {
        switch self {
        case .beginner_2_0_3_0:       return "2.0–3.0"
        case .intermediate_3_0_3_5:   return "3.0–3.5"
        case .intermediate_3_5_4_0:   return "3.5–4.0"
        case .advanced_4_0_4_5:       return "4.0–4.5"
        case .advanced_4_5_5_0:       return "4.5–5.0"
        case .pro_5_0_plus:           return "5.0+"
        }
    }
}

// MARK: - Skill Benchmark

enum SkillBenchmark {
    /// Static benchmark averages: category → DUPR range → expected rating (0–100)
    static let benchmarks: [SkillCategory: [DUPRRange: Int]] = [
        .dinking: [
            .beginner_2_0_3_0: 25, .intermediate_3_0_3_5: 40,
            .intermediate_3_5_4_0: 55, .advanced_4_0_4_5: 68,
            .advanced_4_5_5_0: 78, .pro_5_0_plus: 88
        ],
        .drops: [
            .beginner_2_0_3_0: 20, .intermediate_3_0_3_5: 35,
            .intermediate_3_5_4_0: 48, .advanced_4_0_4_5: 62,
            .advanced_4_5_5_0: 74, .pro_5_0_plus: 85
        ],
        .drives: [
            .beginner_2_0_3_0: 28, .intermediate_3_0_3_5: 42,
            .intermediate_3_5_4_0: 55, .advanced_4_0_4_5: 66,
            .advanced_4_5_5_0: 76, .pro_5_0_plus: 86
        ],
        .defense: [
            .beginner_2_0_3_0: 22, .intermediate_3_0_3_5: 36,
            .intermediate_3_5_4_0: 50, .advanced_4_0_4_5: 64,
            .advanced_4_5_5_0: 75, .pro_5_0_plus: 86
        ],
        .offense: [
            .beginner_2_0_3_0: 30, .intermediate_3_0_3_5: 44,
            .intermediate_3_5_4_0: 57, .advanced_4_0_4_5: 68,
            .advanced_4_5_5_0: 78, .pro_5_0_plus: 88
        ],
        .strategy: [
            .beginner_2_0_3_0: 18, .intermediate_3_0_3_5: 32,
            .intermediate_3_5_4_0: 46, .advanced_4_0_4_5: 60,
            .advanced_4_5_5_0: 72, .pro_5_0_plus: 84
        ],
        .serves: [
            .beginner_2_0_3_0: 30, .intermediate_3_0_3_5: 45,
            .intermediate_3_5_4_0: 58, .advanced_4_0_4_5: 70,
            .advanced_4_5_5_0: 80, .pro_5_0_plus: 90
        ]
    ]

    /// Resolve the current player's DUPR range: live DUPR first, then onboarding profile
    static func forCurrentPlayer() -> DUPRRange? {
        if let singlesRating = DUPRService.shared.profile?.singlesRating {
            return DUPRRange.from(numericRating: singlesRating)
        }
        return DUPRRange.from(profileString: PlayerProfile.current().duprRange)
    }

    /// Compare a user's rating against the benchmark for their DUPR range and skill category
    static func comparison(userRating: Int, category: SkillCategory) -> (benchmark: Int, delta: Int)? {
        guard let range = forCurrentPlayer(),
              let benchmark = benchmarks[category]?[range] else { return nil }
        return (benchmark: benchmark, delta: userRating - benchmark)
    }
}
