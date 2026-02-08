import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 1.0
    @State private var backgroundOpacity: Double = 1.0

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            // Gradient background matching the app icon's teal-green palette
            LinearGradient(
                colors: [
                    Color(hex: "7EC8C4"),
                    Color(hex: "A8D5A0"),
                    Color(hex: "D4E4A0")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Image("AppIconImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
        .opacity(backgroundOpacity)
        .task {
            // Phase 1: Zoom in with spring
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
            }

            // Phase 2: Hold, then fade out
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                iconScale = 1.15
                iconOpacity = 0.0
            }
            withAnimation(.easeInOut(duration: 0.6)) {
                backgroundOpacity = 0.0
            }

            // Phase 3: Complete
            try? await Task.sleep(for: .seconds(0.7))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}
