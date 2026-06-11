import SwiftUI

/// Mon-Sun strip showing session type labels for each day.
/// Highlights today, shows checkmarks for completed days.
struct WeekScheduleStrip: View {
    let weekPlan: WeekPlan
    let todayDayOfWeek: Int // 1 = Monday

    var body: some View {
        HStack(spacing: AppSpacing.xxxs) {
            ForEach(weekPlan.days) { day in
                dayCell(day)
            }
        }
        .padding(AppSpacing.xs)
        .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
    }

    private func dayCell(_ day: ScheduledDay) -> some View {
        let isToday = day.dayOfWeek == todayDayOfWeek
        let isPast = day.dayOfWeek < todayDayOfWeek

        return VStack(spacing: 4) {
            Text(day.dayAbbreviation)
                .font(AppTypography.pillLabel)
                .foregroundStyle(isToday ? AppColors.primary : AppColors.textSecondary)

            if day.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.successGreen)
            } else if day.sessionType == .rest {
                Image(systemName: "moon.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.lockedGray)
            } else {
                Text(day.sessionType.shortLabel)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isPast ? AppColors.lockedGray : AppColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusSm)
                .fill(isToday ? AppColors.primaryTint : Color.clear)
        )
    }
}
