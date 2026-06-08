import SwiftUI

struct ProgramDrillRow: View {
    let drill: ProgramDrill
    var onComplete: (() -> Void)?
    var onSkip: (() -> Void)?
    var onIncrementRep: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xs) {
                statusIndicator

                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(drill.status == .completed ? AppColors.textSecondary : AppColors.textPrimary)
                        .strikethrough(drill.status == .completed)
                        .lineLimit(2)

                    if !drill.drillDescription.isEmpty {
                        Text(drill.drillDescription)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.xs) {
                // Metadata pills
                HStack(spacing: 6) {
                    Label("\(drill.durationMinutes) min", systemImage: "clock")
                    if !drill.equipment.isEmpty {
                        Label(drill.equipment, systemImage: "sportscourt")
                    }
                    if drill.playerCount > 1 {
                        Label("\(drill.playerCount)p", systemImage: "person.2")
                    }
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if drill.status == .pending {
                    // Rep counter or action buttons
                    if drill.targetReps > 1 {
                        Button {
                            onIncrementRep?()
                        } label: {
                            Text("\(drill.completedReps)/\(drill.targetReps)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppColors.primary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        onComplete?()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSkip?()
                    } label: {
                        Text("Skip")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.textSecondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppSpacing.sm)
        .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch drill.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.successGreen)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.textSecondary)
        case .pending:
            Image(systemName: "circle")
                .font(.system(size: 18))
                .foregroundStyle(AppColors.primary.opacity(0.4))
        }
    }
}
