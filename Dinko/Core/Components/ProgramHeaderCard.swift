import SwiftUI

struct ProgramHeaderCard: View {
    let program: Program
    let completedSessions: Int
    let totalSessions: Int

    private var progress: Double {
        guard totalSessions > 0 else { return 0 }
        return Double(completedSessions) / Double(totalSessions)
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(AppColors.ringTrack, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.ringGradientStart, AppColors.ringGradientEnd],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text("Week \(program.currentWeek) of \(program.totalWeeks)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Text("\(completedSessions)/\(totalSessions) sessions")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .heroCard()
    }
}
