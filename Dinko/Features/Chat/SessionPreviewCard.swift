import SwiftUI

struct SessionPreviewCard: View {
    let preview: SessionPreview
    let onConfirm: () -> Void
    let onRetry: () -> Void
    let onToggleDrill: (Int) -> Void
    let onToggleSkillUpdate: (Int) -> Void

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

            // Subskill Suggestions
            if let suggestions = preview.subskillSuggestions, !suggestions.isEmpty {
                subskillSuggestionsSection(suggestions)
            }

            // Skill Creation Suggestions
            if let skillSuggestions = preview.skillSuggestions, !skillSuggestions.isEmpty {
                skillSuggestionsSection(skillSuggestions)
            }

            // Saturated skills warning
            if !preview.saturatedSkills.isEmpty {
                saturatedSkillsSection
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

            ForEach(Array(preview.skillUpdates.enumerated()), id: \.element.skillId) { index, update in
                let isSelected = preview.selectedSkillUpdateIndices.contains(index)
                let isPending = preview.confirmState == .pending

                HStack(spacing: AppSpacing.xxs) {
                    Button {
                        if isPending {
                            onToggleSkillUpdate(index)
                        }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppColors.teal : AppColors.textSecondary)
                            .font(.system(size: 18))
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isPending)

                    Text(update.skill)
                        .font(AppTypography.body)
                        .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                    Spacer()

                    Text("\(update.old)%")
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)

                    Text("\(update.new)%")
                        .font(AppTypography.headline)
                        .foregroundStyle(isSelected
                            ? (update.delta >= 0 ? AppColors.successGreen : AppColors.coral)
                            : AppColors.textSecondary)

                    deltaLabel(update.delta)
                }

                if isSelected {
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
    }

    // MARK: - Drills

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Recommended Drills")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(Array(preview.drillRecommendations.enumerated()), id: \.element.name) { index, drill in
                let isSelected = preview.selectedDrillIndices.contains(index)
                let isPending = preview.confirmState == .pending

                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Button {
                        if isPending {
                            onToggleDrill(index)
                        }
                    } label: {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? AppColors.teal : AppColors.textSecondary)
                            .font(.system(size: 18))
                            .frame(width: 24)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isPending)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(drill.name)
                            .font(AppTypography.body)
                            .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

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

    // MARK: - Subskill Suggestions

    private func subskillSuggestionsSection(_ suggestions: [SubskillSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Suggested Subskills")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(suggestions, id: \.name) { suggestion in
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.teal)
                        .font(.system(size: 14))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(AppTypography.body)

                        Text(suggestion.description)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)

                        if suggestion.suggestedRating > 0 {
                            Text("Starting at \(suggestion.suggestedRating)%")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.teal)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xxxs)
            }
        }
    }

    // MARK: - Skill Suggestions

    private func skillSuggestionsSection(_ suggestions: [SkillCreationSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("New Skills")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)

            ForEach(suggestions, id: \.name) { suggestion in
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Image(systemName: "star.circle.fill")
                        .foregroundStyle(AppColors.teal)
                        .font(.system(size: 14))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.name)
                            .font(AppTypography.body)

                        Text("\(suggestion.category.capitalized) \u{2022} \(suggestion.description)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)

                        if suggestion.suggestedRating > 0 {
                            Text("Starting at \(suggestion.suggestedRating)%")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.teal)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xxxs)
            }
        }
    }

    // MARK: - Saturated Skills

    private var saturatedSkillsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            ForEach(preview.saturatedSkills, id: \.skillName) { info in
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 13))
                        .frame(width: 20)

                    Text("\(info.skillName) has \(info.pendingCount) pending drills — complete or remove some before we add more!")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.xs)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

}
