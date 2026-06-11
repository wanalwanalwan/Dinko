import Foundation

/// Simple XP tracking system. Persists total XP in UserDefaults.
/// Level = totalXP / 100.
enum XPManager {
    private static let xpKey = "pkkl_total_xp"

    /// XP rewards for different actions
    enum Action {
        case learn         // 10 XP
        case practice      // 15 XP
        case apply         // 20 XP
        case play          // 25 XP
        case checkIn       // 5 XP
        case checker       // 5 XP
        case skillAtTarget // 20 XP

        var xpAmount: Int {
            switch self {
            case .learn: return 10
            case .practice: return 15
            case .apply: return 20
            case .play: return 25
            case .checkIn: return 5
            case .checker: return 5
            case .skillAtTarget: return 20
            }
        }
    }

    static var totalXP: Int {
        UserDefaults.standard.integer(forKey: xpKey)
    }

    static var currentLevel: Int {
        totalXP / 100
    }

    static var xpInCurrentLevel: Int {
        totalXP % 100
    }

    static var xpToNextLevel: Int {
        100 - xpInCurrentLevel
    }

    /// Award XP for an action. Returns the new total.
    @discardableResult
    static func award(_ action: Action) -> Int {
        let newTotal = totalXP + action.xpAmount
        UserDefaults.standard.set(newTotal, forKey: xpKey)
        return newTotal
    }

    /// Award XP for completing a session of a given type.
    @discardableResult
    static func awardForSession(type: SessionType) -> Int {
        switch type {
        case .learn: return award(.learn)
        case .practice: return award(.practice)
        case .apply: return award(.apply)
        case .play: return award(.play)
        case .game: return award(.play)
        case .drill: return award(.practice)
        case .rest: return totalXP // no XP for rest
        }
    }

    /// Reset XP (for testing or account reset).
    static func reset() {
        UserDefaults.standard.set(0, forKey: xpKey)
    }
}
