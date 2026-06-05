import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var tint: Color = AppColors.primary

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Inset groove track
                Capsule()
                    .fill(AppColors.background)
                    .frame(height: 8)
                    .overlay(
                        Capsule()
                            .stroke(AppColors.background, lineWidth: 0.5)
                            .shadow(
                                color: AppColors.neumorphicInnerDark.opacity(0.5),
                                radius: 2, x: 1, y: 1
                            )
                            .shadow(
                                color: AppColors.neumorphicInnerLight.opacity(0.5),
                                radius: 2, x: -1, y: -1
                            )
                            .clipShape(Capsule())
                    )

                // Fill with subtle glow
                if animatedProgress > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * animatedProgress, height: 8)
                        .shadow(color: tint.opacity(0.3), radius: 3, x: 0, y: 0)
                }
            }
        }
        .frame(height: 8)
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = targetProgress
            }
        }
        .onChange(of: progress) {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = targetProgress
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress \(Int(progress * 100)) percent")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

#Preview {
    VStack(spacing: 16) {
        ProgressBar(progress: 0.0)
        ProgressBar(progress: 0.25)
        ProgressBar(progress: 0.5)
        ProgressBar(progress: 0.75)
        ProgressBar(progress: 1.0)
    }
    .padding()
    .background(AppColors.background)
}
