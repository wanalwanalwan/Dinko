import SwiftUI

enum AppAnimations {
    // MARK: - Spring Presets

    /// Button presses, toggles — snappy feedback
    static let springSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Card expansions, content reveals — smooth and natural
    static let springSmooth = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Celebrations, achievements — playful bounce
    static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// List stagger children — gentle cascade
    static let springGentle = Animation.spring(response: 0.35, dampingFraction: 0.85)

    // MARK: - Timing Presets

    /// Quick content fade-in
    static let fadeIn = Animation.easeOut(duration: 0.25)

    // MARK: - Stagger

    /// Delay for staggered list item at given index, capped at 0.4s
    static func staggerDelay(for index: Int) -> Double {
        min(Double(index) * 0.05, 0.4)
    }

    // MARK: - Scale

    /// Button press feedback scale
    static let pressedScale: CGFloat = 0.97
}
