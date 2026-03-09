import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var tint: Color = AppColors.teal

    @State private var animatedProgress: Double = 0

    private var targetProgress: Double { min(max(progress, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.separator)
                    .frame(height: 8)

                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
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
}
