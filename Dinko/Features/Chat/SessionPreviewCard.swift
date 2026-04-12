import SwiftUI

struct SessionPreviewCard: View {
    let preview: SessionPreview
    let onConfirm: () -> Void
    let onRetry: () -> Void
    let onToggleDrill: (Int) -> Void
    let onToggleSkillUpdate: (Int) -> Void
    let onToggleSubskill: (Int, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            Label("Session Analysis", systemImage: "sparkles")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.teal)

            // Coach Insight
            if let insight = preview.coachInsight, !insight.isEmpty {
                Text(insight)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(AppSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.teal.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session analysis with \(preview.skillUpdates.count) skill updates and \(preview.drillRecommendations.count) drill recommendations")
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
                let effective = preview.effectiveSkillValues(for: index)

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

                    Text("\(effective.new)%")
                        .font(AppTypography.headline)
                        .foregroundStyle(isSelected
                            ? (effective.delta >= 0 ? AppColors.successGreen : AppColors.coral)
                            : AppColors.textSecondary)

                    formattedDeltaLabel(effective.delta)
                }

                if isSelected {
                    ForEach(Array(update.subskillDeltas.enumerated()), id: \.element.name) { subIndex, sub in
                        let isSubSelected = preview.selectedSubskillIndices[index]?.contains(subIndex) ?? true

                        HStack {
                            Button {
                                if isPending {
                                    onToggleSubskill(index, subIndex)
                                }
                            } label: {
                                Image(systemName: isSubSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSubSelected ? AppColors.teal : AppColors.textSecondary)
                                    .font(.system(size: 14))
                                    .frame(width: 20)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isPending)
                            .padding(.leading, AppSpacing.sm)

                            Text(sub.name)
                                .font(AppTypography.caption)
                                .foregroundStyle(isSubSelected ? AppColors.textSecondary : AppColors.textSecondary.opacity(0.5))

                            Spacer()

                            Text("\(sub.old)%")
                                .font(AppTypography.caption)
                                .foregroundStyle(isSubSelected ? AppColors.textSecondary : AppColors.textSecondary.opacity(0.5))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundStyle(isSubSelected ? AppColors.textSecondary : AppColors.textSecondary.opacity(0.5))

                            Text("\(sub.new)%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSubSelected
                                    ? (sub.delta >= 0 ? AppColors.successGreen : AppColors.coral)
                                    : AppColors.textSecondary.opacity(0.5))

                            deltaLabel(sub.delta, small: true)
                                .opacity(isSubSelected ? 1.0 : 0.5)
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
                        .foregroundStyle(AppColors.warningOrange)
                        .font(.system(size: 13))
                        .frame(width: 20)

                    Text("\(info.skillName) drill queue is full (\(info.pendingCount) pending) — complete or remove some to get new recommendations.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(AppSpacing.xs)
        .background(AppColors.warningOrange.opacity(0.08))
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
            confirmedBanner

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

    // MARK: - Confirmed Banner

    private var confirmedBanner: some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(AppColors.successGreen)

            Text("Session Logged")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            let skillCount = preview.selectedSkillUpdateIndices.count
            let drillCount = preview.selectedDrillIndices.count
            let parts = [
                skillCount > 0 ? "\(skillCount) skill\(skillCount == 1 ? "" : "s") updated" : nil,
                drillCount > 0 ? "\(drillCount) drill\(drillCount == 1 ? "" : "s") added" : nil
            ].compactMap { $0 }

            if !parts.isEmpty {
                Text(parts.joined(separator: " \u{00B7} "))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.successGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func formattedDeltaLabel(_ delta: Double, small: Bool = false) -> some View {
        let text: String
        if delta.truncatingRemainder(dividingBy: 1) == 0 {
            let intDelta = Int(delta)
            text = intDelta > 0 ? "+\(intDelta)" : "\(intDelta)"
        } else {
            text = delta > 0 ? String(format: "+%.1f", delta) : String(format: "%.1f", delta)
        }
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
