import SwiftUI

enum DrillNodeState {
    case next
    case completed
    case upcoming

    var circleSize: CGFloat {
        switch self {
        case .next: 48
        case .completed: 40
        case .upcoming: 36
        }
    }

    var iconName: String {
        switch self {
        case .next: "play.fill"
        case .completed: "checkmark"
        case .upcoming: "play.fill"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .next: 18
        case .completed: 16
        case .upcoming: 14
        }
    }

    var backgroundColor: Color {
        switch self {
        case .next: AppColors.teal
        case .completed: AppColors.successGreen
        case .upcoming: AppColors.teal
        }
    }
}

struct DrillNodeView: View {
    let drill: Drill
    let state: DrillNodeState
    let skillName: String?

    @State private var glowOpacity: Double = 0.3

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            // Circle node
            ZStack {
                if state == .next {
                    Circle()
                        .fill(state.backgroundColor.opacity(glowOpacity))
                        .frame(width: state.circleSize + 12, height: state.circleSize + 12)
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                glowOpacity = 0.6
                            }
                        }
                }

                Circle()
                    .fill(state.backgroundColor)
                    .frame(width: state.circleSize, height: state.circleSize)

                Image(systemName: state.iconName)
                    .font(.system(size: state.iconSize, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 60)

            // Drill info tile
            VStack(alignment: .leading, spacing: 4) {
                Text(drill.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: AppSpacing.xxs) {
                    Label("\(drill.durationMinutes) min", systemImage: "timer")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    if let skillName {
                        Text("\u{00B7}")
                            .foregroundStyle(AppColors.textSecondary)
                        Text(skillName)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Rep indicator or duration badge
            if drill.targetReps > 1 {
                Text("Rep \(drill.completedReps)/\(drill.targetReps)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.teal.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Text("\(drill.durationMinutes) min")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.teal.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .contentShape(Rectangle())
    }
}

#Preview {
    let sampleDrill = Drill(
        skillId: UUID(),
        name: "Cross-Court Dink Rally",
        durationMinutes: 15
    )

    VStack(spacing: 20) {
        DrillNodeView(drill: sampleDrill, state: .next, skillName: "Dinking")
        DrillNodeView(drill: sampleDrill, state: .completed, skillName: "Dinking")
        DrillNodeView(drill: sampleDrill, state: .upcoming, skillName: "Dinking")
    }
    .padding()
}
