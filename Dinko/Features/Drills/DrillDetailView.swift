import SwiftUI

struct DrillDetailView: View {
    let drill: HomeRecommendedDrill
    let onComplete: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                heroSection
                detailsCard
                if !drill.reason.isEmpty {
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

            Text(drill.drillName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.xs) {
                Label("\(drill.durationMinutes) min", systemImage: "clock")
                Text("\u{00B7}")
                Text(drill.skillName)
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
            if !drill.drillDescription.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    Text("DESCRIPTION")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(drill.drillDescription)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            if let subskill = drill.targetSubskill {
                Divider()
                infoRow(icon: "target", label: "Focus", value: subskill)
            }

            if !drill.equipment.isEmpty {
                Divider()
                infoRow(icon: "wrench.and.screwdriver", label: "Equipment", value: drill.equipment)
            }

            if drill.playerCount > 1 {
                Divider()
                infoRow(icon: "person.2", label: "Players", value: "\(drill.playerCount)")
            }

            Divider()
            infoRow(
                icon: drill.priority == "high" ? "exclamationmark.circle.fill" : "circle.fill",
                label: "Priority",
                value: drill.priority.capitalized,
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
        switch drill.priority {
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

            Text(drill.reason)
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
            Button {
                Task {
                    await onComplete()
                    dismiss()
                }
            } label: {
                Label("Complete Drill", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.teal)
        }
    }
}
