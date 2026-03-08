import SwiftUI

// MARK: - Staggered Appearance

struct StaggeredAppearance: ViewModifier {
    let index: Int
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                withAnimation(
                    AppAnimations.springGentle.delay(AppAnimations.staggerDelay(for: index))
                ) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppAnimations.pressedScale : 1.0)
            .animation(AppAnimations.springSnappy, value: configuration.isPressed)
    }
}

// MARK: - Content Load Transition

struct ContentLoadTransition: ViewModifier {
    let isLoaded: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isLoaded ? 1 : 0)
            .offset(y: isLoaded ? 0 : 8)
            .animation(AppAnimations.fadeIn, value: isLoaded)
    }
}

// MARK: - View Extensions

extension View {
    func staggeredAppearance(index: Int) -> some View {
        modifier(StaggeredAppearance(index: index))
    }

    func contentLoadTransition(isLoaded: Bool) -> some View {
        modifier(ContentLoadTransition(isLoaded: isLoaded))
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}
