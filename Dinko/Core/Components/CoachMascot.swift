import SwiftUI

enum MascotState {
    case idle
    case thinking
    case talking
    case celebrating

    var imageName: String {
        switch self {
        case .idle: "coach-idle"
        case .thinking: "coach-thinking"
        case .talking: "coach-talking"
        case .celebrating: "coach-celebrating"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .idle: "Coach mascot waving"
        case .thinking: "Coach mascot thinking"
        case .talking: "Coach mascot talking"
        case .celebrating: "Coach mascot celebrating"
        }
    }
}

struct CoachMascot: View {
    let state: MascotState
    var size: CGFloat = 36

    @State private var isAnimating = false

    var body: some View {
        Image(state.imageName)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .modifier(MascotAnimation(state: state, isAnimating: isAnimating))
            .accessibilityLabel(state.accessibilityLabel)
            .onAppear {
                switch state {
                case .idle, .thinking:
                    withAnimation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        isAnimating = true
                    }
                case .talking, .celebrating:
                    withAnimation(AppAnimations.springBouncy) {
                        isAnimating = true
                    }
                }
            }
            .onChange(of: state) {
                isAnimating = false
                switch state {
                case .idle, .thinking:
                    withAnimation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                    ) {
                        isAnimating = true
                    }
                case .talking, .celebrating:
                    withAnimation(AppAnimations.springBouncy) {
                        isAnimating = true
                    }
                }
            }
    }
}

private struct MascotAnimation: ViewModifier {
    let state: MascotState
    let isAnimating: Bool

    func body(content: Content) -> some View {
        switch state {
        case .idle:
            content.offset(y: isAnimating ? -8 : 8)
        case .thinking:
            content.scaleEffect(isAnimating ? 1.0 : 0.95)
        case .talking:
            content.offset(y: isAnimating ? -3 : 0)
        case .celebrating:
            content
                .offset(y: isAnimating ? -6 : 0)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        VStack {
            CoachMascot(state: .idle, size: 64)
            Text("Idle").font(.caption)
        }
        VStack {
            CoachMascot(state: .thinking, size: 64)
            Text("Thinking").font(.caption)
        }
        VStack {
            CoachMascot(state: .talking, size: 64)
            Text("Talking").font(.caption)
        }
        VStack {
            CoachMascot(state: .celebrating, size: 64)
            Text("Celebrating").font(.caption)
        }
    }
    .padding()
}
