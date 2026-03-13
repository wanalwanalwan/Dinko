import SwiftUI

struct TrainingSummaryCard: View {
    let pendingCount: Int
    let totalMinutes: Int
    let focusSkill: String?
    let completedCount: Int
    let progress: Double

    private var totalCount: Int { completedCount + pendingCount }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Today's Training")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            // Stats row
            HStack(spacing: AppSpacing.sm) {
                statItem(icon: "flame.fill", value: "\(totalCount)", label: "Drills", color: AppColors.coral)
                statItem(icon: "clock", value: "\(totalMinutes)", label: "min", color: AppColors.teal)
                if let focusSkill {
                    statItem(icon: "target", value: focusSkill, label: "Focus", color: AppColors.drillPurple)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                ProgressBar(progress: progress)

                Text("\(completedCount) of \(totalCount) completed")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func statItem(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TrainingSummaryCard(
            pendingCount: 4,
            totalMinutes: 45,
            focusSkill: "Dinking",
            completedCount: 2,
            progress: 0.33
        )

        TrainingSummaryCard(
            pendingCount: 1,
            totalMinutes: 10,
            focusSkill: nil,
            completedCount: 0,
            progress: 0
        )
    }
    .padding()
    .background(AppColors.background)
}
