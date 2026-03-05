import SwiftUI

struct DrillCardView: View {
    let drill: HomeRecommendedDrill

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack {
                    drillTypePill
                    Spacer()
                    Text("\(drill.durationMinutes) min")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Text(drill.drillName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                VStack(alignment: .leading, spacing: 2) {
                    metadataRow("Focus", value: drill.targetSubskill ?? drill.skillName)
                    metadataRow("Level", value: difficultyLabel)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Drill Type Pill

    private var drillTypePill: some View {
        let info = drillTypeInfo
        return Text("\(info.icon) \(info.label)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(info.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(info.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var drillTypeInfo: (icon: String, label: String, color: Color) {
        let lower = drill.drillName.lowercased()
        if lower.contains("reflex") || lower.contains("reaction") {
            return ("⚡", "Reflex", .orange)
        }
        if lower.contains("placement") || lower.contains("target") || lower.contains("accuracy") {
            return ("🎯", "Placement", Color(hex: "4A6CF7"))
        }
        if lower.contains("power") || lower.contains("smash") || lower.contains("speed") {
            return ("🔥", "Power", AppColors.coral)
        }
        if lower.contains("dink") || lower.contains("drop") || lower.contains("touch") || lower.contains("soft") {
            return ("🎯", "Touch", AppColors.successGreen)
        }
        if lower.contains("strategy") || lower.contains("position") || lower.contains("transition") {
            return ("🧠", "Strategy", .purple)
        }
        if lower.contains("serve") || lower.contains("return") {
            return ("🎯", "Serve", Color(hex: "4A6CF7"))
        }
        if lower.contains("drive") || lower.contains("attack") {
            return ("🔥", "Attack", AppColors.coral)
        }
        if lower.contains("counter") {
            return ("⚡", "Counter", .orange)
        }
        return ("🏸", "Drill", Color(hex: "4A6CF7"))
    }

    private var difficultyLabel: String {
        switch drill.priority {
        case "high": "Advanced"
        case "medium": "Intermediate"
        default: "Beginner"
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
