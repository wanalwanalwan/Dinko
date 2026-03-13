import SwiftUI

struct DrillDetailView: View {
    private let drillName: String
    private let skillName: String
    private let durationMinutes: Int
    private let priority: String
    private let drillDescription: String
    private let equipment: String
    private let playerCount: Int
    private let reason: String
    private let targetSubskill: String?
    private let targetReps: Int
    private let completedReps: Int
    private let onComplete: () async -> Void
    private let onSkip: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Existing init for HomeRecommendedDrill (HomeView compatibility)
    init(drill: HomeRecommendedDrill, onComplete: @escaping () async -> Void) {
        self.drillName = drill.drillName
        self.skillName = drill.skillName
        self.durationMinutes = drill.durationMinutes
        self.priority = drill.priority
        self.drillDescription = drill.drillDescription
        self.equipment = drill.equipment
        self.playerCount = drill.playerCount
        self.reason = drill.reason
        self.targetSubskill = drill.targetSubskill
        self.targetReps = 1
        self.completedReps = 0
        self.onComplete = onComplete
        self.onSkip = nil
    }

    // New init for Drill type (DrillQueueView)
    init(drill: Drill, skillName: String, onComplete: @escaping () async -> Void, onSkip: @escaping () async -> Void) {
        self.drillName = drill.name
        self.skillName = skillName
        self.durationMinutes = drill.durationMinutes
        self.priority = drill.priority
        self.drillDescription = drill.drillDescription
        self.equipment = drill.equipment
        self.playerCount = drill.playerCount
        self.reason = drill.reason
        self.targetSubskill = drill.targetSubskill
        self.targetReps = drill.targetReps
        self.completedReps = drill.completedReps
        self.onComplete = onComplete
        self.onSkip = onSkip
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                heroSection
                detailsCard
                if !reason.isEmpty {
                    reasonCard
                }
                actionButtons
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, AppSpacing.xl)
        }
        .navigationTitle("Drill Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.teal)

            Text(drillName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.xs) {
                Label("\(durationMinutes) min", systemImage: "clock")
                Text("\u{00B7}")
                Text(skillName)
                    .foregroundStyle(AppColors.teal)
            }
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if !drillDescription.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    Text("DESCRIPTION")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(drillDescription)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            if let subskill = targetSubskill {
                Divider()
                infoRow(icon: "target", label: "Focus", value: subskill)
            }

            if !equipment.isEmpty {
                Divider()
                infoRow(icon: "wrench.and.screwdriver", label: "Equipment", value: equipment)
            }

            if playerCount > 1 {
                Divider()
                infoRow(icon: "person.2", label: "Players", value: "\(playerCount)")
            }

            Divider()
            infoRow(
                icon: priority == "high" ? "exclamationmark.circle.fill" : "circle.fill",
                label: "Priority",
                value: priority.capitalized,
                valueColor: priorityColor
            )
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func infoRow(icon: String, label: String, value: String, valueColor: Color = AppColors.textPrimary) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.teal)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }

    private var priorityColor: Color {
        switch priority {
        case "high": AppColors.coral
        case "medium": AppColors.teal
        default: AppColors.textSecondary
        }
    }

    // MARK: - Reason Card

    private var reasonCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            Text("WHY THIS DRILL?")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Text(reason)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.xs) {
            if targetReps > 1 {
                Text("Rep \(completedReps + 1) of \(targetReps)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.coral)
            }

            Button {
                Task {
                    await onComplete()
                    dismiss()
                }
            } label: {
                Label("Do Drill", systemImage: "play.circle.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.teal)

            if let onSkip {
                Button {
                    Task {
                        await onSkip()
                        dismiss()
                    }
                } label: {
                    Label("Skip Drill", systemImage: "forward.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.textSecondary)
            }
        }
    }
}
