import SwiftUI

enum DrillNodeState {
    case next
    case completed
    case locked

    var circleSize: CGFloat {
        switch self {
        case .next: 48
        case .completed: 40
        case .locked: 36
        }
    }

    var iconName: String {
        switch self {
        case .next: "play.fill"
        case .completed: "checkmark"
        case .locked: "lock.fill"
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .next: 18
        case .completed: 16
        case .locked: 14
        }
    }

    var backgroundColor: Color {
        switch self {
        case .next: AppColors.teal
        case .completed: AppColors.successGreen
        case .locked: AppColors.lockedGray
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
                    .foregroundStyle(state == .locked ? AppColors.textSecondary : AppColors.textPrimary)
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
                            .foregroundStyle(state == .locked ? AppColors.textSecondary : AppColors.teal)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // XP badge
            Text("+\(drill.durationMinutes * 2) XP")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(state == .locked ? AppColors.textSecondary : AppColors.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((state == .locked ? AppColors.lockedGray : AppColors.teal).opacity(0.12))
                .clipShape(Capsule())
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
        DrillNodeView(drill: sampleDrill, state: .locked, skillName: "Dinking")
    }
    .padding()
}
