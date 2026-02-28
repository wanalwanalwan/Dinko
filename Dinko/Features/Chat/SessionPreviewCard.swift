import SwiftUI

struct SessionPreviewCard: View {
    let preview: SessionPreview
    let onConfirm: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            Label("Session Analysis", systemImage: "sparkles")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.teal)

            Divider()

            // Skill Updates
            if !preview.skillUpdates.isEmpty {
                skillUpdatesSection
            }

            // Drill Recommendations
            if !preview.drillRecommendations.isEmpty {
                drillsSection
            }

            // Roadmap
            if let roadmap = preview.roadmapUpdates {
                roadmapSection(roadmap)
            }

            Divider()

            // Action Buttons
            actionButtons
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Skill Updates

    private var skillUpdatesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Skill Changes")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(preview.skillUpdates, id: \.skillId) { update in
                HStack {
                    Text(update.skill)
                        .font(AppTypography.body)

                    Spacer()

                    Text("\(update.old)%")
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("\(update.new)%")
                        .font(AppTypography.headline)
                        .foregroundStyle(update.delta >= 0 ? AppColors.successGreen : AppColors.coral)

                    deltaLabel(update.delta)
                }

                // Subskill deltas indented
                ForEach(update.subskillDeltas, id: \.name) { sub in
                    HStack {
                        Text(sub.name)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.leading, AppSpacing.lg)

                        Spacer()

                        Text("\(sub.old)%")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(sub.new)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(sub.delta >= 0 ? AppColors.successGreen : AppColors.coral)

                        deltaLabel(sub.delta, small: true)
                    }
                }
            }
        }
    }

    // MARK: - Drills

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Recommended Drills")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(preview.drillRecommendations, id: \.name) { drill in
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Image(systemName: priorityIcon(drill.priority))
                        .foregroundStyle(priorityColor(drill.priority))
                        .font(.system(size: 14))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(drill.name)
                            .font(AppTypography.body)

                        Text("\(drill.durationMinutes) min \u{2022} \(drill.targetSkill)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xxxs)
            }
        }
    }

    // MARK: - Roadmap

    private func roadmapSection(_ roadmap: RoadmapUpdates) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if let focus = roadmap.weeklyFocus {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "target")
                        .foregroundStyle(AppColors.teal)
                    VStack(alignment: .leading) {
                        Text("Weekly Focus")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text(focus.title)
                            .font(AppTypography.body)
                    }
                }
            }

            ForEach(roadmap.milestones, id: \.title) { milestone in
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "flag.fill")
                        .foregroundStyle(AppColors.coral)
                        .font(.system(size: 12))
                    Text(milestone.title)
                        .font(AppTypography.caption)
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch preview.confirmState {
        case .pending:
            HStack(spacing: AppSpacing.xs) {
                Button(action: onConfirm) {
                    Label("Confirm", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.teal)

                Button(action: onRetry) {
                    Label("Redo", systemImage: "arrow.counterclockwise")
                        .font(AppTypography.callout)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.bordered)
            }

        case .confirming:
            HStack {
                Spacer()
                ProgressView()
                    .padding(.trailing, AppSpacing.xxs)
                Text("Applying changes...")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
            .padding(.vertical, AppSpacing.xxs)

        case .confirmed:
            Label("Changes applied", systemImage: "checkmark.circle.fill")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.successGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxs)

        case .failed(let message):
            VStack(spacing: AppSpacing.xxs) {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.coral)

                Button(action: onConfirm) {
                    Label("Retry", systemImage: "arrow.counterclockwise")
                        .font(AppTypography.callout)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.coral)
            }
        }
    }

    // MARK: - Helpers

    private func deltaLabel(_ delta: Int, small: Bool = false) -> some View {
        let text = delta > 0 ? "+\(delta)" : "\(delta)"
        let color = delta >= 0 ? AppColors.successGreen : AppColors.coral
        return Text(text)
            .font(small ? AppTypography.caption : AppTypography.trendValue)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func priorityIcon(_ priority: String) -> String {
        switch priority {
        case "high": "exclamationmark.circle.fill"
        case "medium": "circle.fill"
        default: "circle"
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "high": AppColors.coral
        case "medium": AppColors.teal
        default: AppColors.textSecondary
        }
    }
}
