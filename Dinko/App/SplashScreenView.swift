import SwiftUI

struct SplashScreenView: View {
    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 1.0
    @State private var backgroundOpacity: Double = 1.0

    /// Static flag survives SwiftUI view recreation (parent re-evaluation)
    private static var hasAnimated = false

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            Image("coach-idle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 180, height: 180)
                .shadow(color: AppColors.neumorphicDark.opacity(0.5), radius: 20, x: 6, y: 10)
                .shadow(color: AppColors.neumorphicLight.opacity(0.4), radius: 12, x: -4, y: -6)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
        .opacity(backgroundOpacity)
        .task {
            guard !Self.hasAnimated else {
                onFinished()
                return
            }
            Self.hasAnimated = true

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
