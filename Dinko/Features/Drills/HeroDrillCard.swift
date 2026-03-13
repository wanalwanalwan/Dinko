import SwiftUI

struct HeroDrillCard: View {
    let drill: Drill
    let skillName: String?
    let totalCompleted: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header row
            HStack {
                Text("UP NEXT")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
                    .tracking(0.5)

                Spacer()

                Label("\(totalCompleted) Completed", systemImage: "figure.pickleball")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.teal.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Drill name
            Text(drill.name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3)

            // Subskill / focus
            if let subskill = drill.targetSubskill, !subskill.isEmpty {
                Text(subskill)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            // Rep progress (multi-rep drills only)
            if drill.targetReps > 1 {
                Text("Rep \(drill.completedReps + 1) of \(drill.targetReps)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.coral)
            }

            // Meta row
            HStack(spacing: AppSpacing.xs) {
                Label("\(drill.durationMinutes) min", systemImage: "clock")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                if let skillName {
                    skillPill(skillName)
                }

                if drill.priority == "high" {
                    Text("HIGH")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.coral.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // CTA button
            HStack {
                Spacer()
                Label("START DRILL", systemImage: "play.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.teal)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
    }

    private func skillPill(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(AppColors.teal)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColors.teal.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    let drill = Drill(
        skillId: UUID(),
        name: "Cross-Court Dink Rally with Reset",
        targetSubskill: "Backhand dink consistency",
        durationMinutes: 15,
        priority: "high"
    )

    HeroDrillCard(drill: drill, skillName: "Dinking", totalCompleted: 12)
        .padding()
        .background(AppColors.background)
}
