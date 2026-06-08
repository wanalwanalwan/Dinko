import SwiftUI

struct WeekSessionCard: View {
    let session: ProgramSession
    let drillCount: Int

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            statusIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(session.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)

                if !session.focus.isEmpty {
                    Text(session.focus)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label("\(session.estimatedMinutes) min", systemImage: "clock")
                    Label("\(drillCount) drills", systemImage: "list.bullet")
                }
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            if session.status == .available {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(AppSpacing.sm)
        .sessionCardStyle(for: session.status)
        .opacity(session.status == .locked ? 0.6 : 1.0)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch session.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.successGreen)
        case .available:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.primary)
        case .locked:
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(AppColors.lockedGray)
        }
    }

    private var titleColor: Color {
        switch session.status {
        case .locked: AppColors.textSecondary
        case .available, .completed: AppColors.textPrimary
        }
    }
}

private extension View {
    @ViewBuilder
    func sessionCardStyle(for status: ProgramSessionStatus) -> some View {
        switch status {
        case .locked:
            self.neumorphicInset(depth: .shallow, cornerRadius: AppSpacing.cornerRadiusMd)
        case .available:
            self.neumorphicTinted(color: AppColors.primary, cornerRadius: AppSpacing.cornerRadiusMd)
        case .completed:
            self.neumorphicTinted(
                color: AppColors.successGreen,
                tintOpacity: 0.04,
                borderOpacity: 0.12,
                cornerRadius: AppSpacing.cornerRadiusMd
            )
        }
    }
}
