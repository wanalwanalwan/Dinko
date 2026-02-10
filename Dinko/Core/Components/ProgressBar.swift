import SwiftUI

struct ProgressBar: View {
    let progress: Double
    var tint: Color = AppColors.teal

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemFill))
                    .frame(height: 8)

                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 8)
            }
        }
        .frame(height: 8)
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
