import Foundation

/// Confidence benchmark targets per canonical skill per target DUPR.
/// Replaces the old 0-100 SkillBenchmark system with 1-10 confidence targets.
enum ConfidenceBenchmark {

    /// Target DUPR levels users can set as their goal
    enum TargetDUPR: String, CaseIterable, Codable {
        case dupr3_0 = "3.0"
        case dupr3_5 = "3.5"
        case dupr4_0 = "4.0"
        case dupr4_5 = "4.5"
        case dupr5_0 = "5.0"

        var displayName: String { rawValue }

        var numericValue: Double {
            switch self {
            case .dupr3_0: return 3.0
            case .dupr3_5: return 3.5
            case .dupr4_0: return 4.0
            case .dupr4_5: return 4.5
            case .dupr5_0: return 5.0
            }
        }
    }

    /// Benchmark confidence target (1-10) for a canonical skill at a given target DUPR.
    /// Returns nil if the skill is not tracked at that DUPR level.
    static func target(canonicalId: String, targetDUPR: TargetDUPR) -> Int? {
        benchmarks[canonicalId]?[targetDUPR]
    }

    /// Pillar importance weight for the recommendation engine.
    /// Higher weight = pillar gaps matter more at this DUPR level.
    static func pillarWeight(pillar: SkillPillar, targetDUPR: TargetDUPR) -> Double {
        let weights: [SkillPillar: [TargetDUPR: Double]] = [
            .consistency: [.dupr3_0: 2.0, .dupr3_5: 2.0, .dupr4_0: 1.5, .dupr4_5: 1.0, .dupr5_0: 0.5],
            .transition:  [.dupr3_0: 1.0, .dupr3_5: 1.5, .dupr4_0: 2.0, .dupr4_5: 1.5, .dupr5_0: 1.0],
            .attack:      [.dupr3_0: 0.5, .dupr3_5: 0.5, .dupr4_0: 1.0, .dupr4_5: 2.0, .dupr5_0: 1.5],
            .movement:    [.dupr3_0: 1.0, .dupr3_5: 1.0, .dupr4_0: 1.5, .dupr4_5: 1.5, .dupr5_0: 2.0],
            .strategy:    [.dupr3_0: 0.5, .dupr3_5: 0.5, .dupr4_0: 1.0, .dupr4_5: 1.5, .dupr5_0: 2.0]
        ]
        return weights[pillar]?[targetDUPR] ?? 1.0
    }

    /// Parse a goal DUPR string (e.g. "4.0") into a TargetDUPR
    static func targetDUPR(from goalString: String?) -> TargetDUPR? {
        guard let goalString else { return nil }
        return TargetDUPR(rawValue: goalString)
    }

    // MARK: - Benchmark Data

    /// canonicalId -> [TargetDUPR: confidence target (1-10)]
    private static let benchmarks: [String: [TargetDUPR: Int]] = [
        // Consistency pillar
        "serve_consistency":     [.dupr3_0: 4, .dupr3_5: 5, .dupr4_0: 7, .dupr4_5: 8, .dupr5_0: 9],
        "return_consistency":    [.dupr3_0: 4, .dupr3_5: 5, .dupr4_0: 7, .dupr4_5: 8, .dupr5_0: 9],
        "dink_rallies":          [.dupr3_0: 3, .dupr3_5: 5, .dupr4_0: 7, .dupr4_5: 8, .dupr5_0: 9],
        "volley_consistency":    [.dupr3_0: 3, .dupr3_5: 5, .dupr4_0: 6, .dupr4_5: 8, .dupr5_0: 9],

        // Transition pillar
        "third_shot_drop":       [.dupr3_0: 2, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 8, .dupr5_0: 9],
        "resets":                [.dupr3_0: 2, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 7, .dupr5_0: 9],
        "approach_shots":        [.dupr3_0: 2, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 8],
        "shot_selection":        [.dupr3_0: 2, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 7, .dupr5_0: 9],

        // Attack pillar
        "drives":                [.dupr3_0: 3, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 7, .dupr5_0: 9],
        "speed_ups":             [.dupr3_0: 2, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 8],
        "counters":              [.dupr3_0: 2, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 9],
        "roll_volleys":          [.dupr3_0: 1, .dupr3_5: 2, .dupr4_0: 4, .dupr4_5: 6, .dupr5_0: 8],
        "atp":                   [.dupr3_0: 1, .dupr3_5: 1, .dupr4_0: 3, .dupr4_5: 5, .dupr5_0: 7],
        "erne":                  [.dupr3_0: 1, .dupr3_5: 1, .dupr4_0: 3, .dupr4_5: 5, .dupr5_0: 7],

        // Movement pillar
        "split_step":            [.dupr3_0: 3, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 7, .dupr5_0: 9],
        "court_positioning":     [.dupr3_0: 3, .dupr3_5: 4, .dupr4_0: 6, .dupr4_5: 8, .dupr5_0: 9],
        "recovery":              [.dupr3_0: 2, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 8],
        "lateral_movement":      [.dupr3_0: 2, .dupr3_5: 4, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 8],

        // Strategy pillar
        "target_selection":      [.dupr3_0: 2, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 8],
        "pattern_play":          [.dupr3_0: 1, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 9],
        "stacking":              [.dupr3_0: 1, .dupr3_5: 2, .dupr4_0: 4, .dupr4_5: 6, .dupr5_0: 8],
        "point_construction":    [.dupr3_0: 1, .dupr3_5: 3, .dupr4_0: 5, .dupr4_5: 7, .dupr5_0: 9],
    ]
}
