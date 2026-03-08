import SwiftUI

struct TimelineView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: TimelineViewModel?
    @State private var contentReady = false

    var body: some View {
        Group {
            if let viewModel {
                timelineContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = TimelineViewModel(
                    journalEntryRepository: dependencies.journalEntryRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadEntries()
            }
        }
    }

    @ViewBuilder
    private func timelineContent(_ viewModel: TimelineViewModel) -> some View {
        if viewModel.dayGroups.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(Array(viewModel.dayGroups.enumerated()), id: \.element.id) { index, group in
                        daySection(group, viewModel: viewModel)
                            .staggeredAppearance(index: index)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .contentLoadTransition(isLoaded: contentReady)
            }
            .refreshable {
                await viewModel.loadEntries()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()

            Image(systemName: "book")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.teal.opacity(0.5))

            Text("No Entries Yet")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Log a session in the Coach tab and confirm it to create your first entry.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }

    private func daySection(_ group: TimelineDayGroup, viewModel: TimelineViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(group.displayDate)
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, AppSpacing.xxxs)

            ForEach(group.entries) { entry in
                TimelineEntryCard(entry: entry)
                    .contextMenu {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteEntry(entry.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
}

// MARK: - Timeline Entry Card

struct TimelineEntryCard: View {
    let entry: JournalEntry
    @State private var isExpanded = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: entry.date)
    }

    /// Parses skill updates from either pipe format "Skill|old|new|+delta"
    /// or legacy format "Skill: old% → new% (+delta)"
    private var parsedSkillUpdates: [(skill: String, old: String, new: String, delta: String)] {
        guard !entry.skillUpdatesSummary.isEmpty else { return [] }
        return entry.skillUpdatesSummary.components(separatedBy: "\n").compactMap { line in
            // New pipe format
            let pipeParts = line.components(separatedBy: "|")
            if pipeParts.count == 4 {
                return (skill: pipeParts[0], old: pipeParts[1], new: pipeParts[2], delta: pipeParts[3])
            }
            // Legacy format: "Dinking: 45% → 52% (+7)"
            let colonParts = line.components(separatedBy: ": ")
            guard colonParts.count == 2 else { return nil }
            let skill = colonParts[0]
            let rest = colonParts[1]
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let arrowParts = rest.components(separatedBy: " \u{2192} ")
            guard arrowParts.count == 2 else { return nil }
            let old = arrowParts[0].trimmingCharacters(in: .whitespaces)
            let newAndDelta = arrowParts[1].components(separatedBy: " ")
            guard newAndDelta.count >= 1 else { return nil }
            let new = newAndDelta[0].trimmingCharacters(in: .whitespaces)
            let delta = newAndDelta.count >= 2 ? newAndDelta[1].trimmingCharacters(in: .whitespaces) : ""
            return (skill: skill, old: old, new: new, delta: delta)
        }
    }

    var body: some View {
        Button {
            withAnimation(AppAnimations.springSmooth) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsed: always visible
                collapsedContent

                // Expanded: details
                if isExpanded {
                    expandedContent
                        .padding(.top, AppSpacing.xs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline entry at \(timeString), \(entry.skillUpdatesCount) skill updates, \(entry.drillsCount) drills")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand details")
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Time row
            HStack {
                Text(timeString)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let sessionType = entry.sessionType, !sessionType.isEmpty {
                    Text(sessionType.capitalized)
                        .font(AppTypography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(AppColors.teal)
                        .padding(.horizontal, AppSpacing.xxs)
                        .padding(.vertical, 2)
                        .background(AppColors.teal.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Skill names with deltas — compact summary
            let updates = parsedSkillUpdates
            if !updates.isEmpty {
                ForEach(updates, id: \.skill) { update in
                    HStack(spacing: AppSpacing.xxs) {
                        Text(update.skill)
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Text("\(update.new)%")
                            .font(AppTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)

                        if !update.delta.isEmpty {
                            Text(update.delta)
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    update.delta.hasPrefix("-") ? AppColors.coral : AppColors.successGreen
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (update.delta.hasPrefix("-") ? AppColors.coral : AppColors.successGreen)
                                        .opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            } else if entry.drillsCount > 0 {
                // No skill updates, but has drills
                Label("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") added",
                      systemImage: "figure.pickleball")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.coral)
            }
        }
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Divider()
                .padding(.bottom, AppSpacing.xxxs)

            // User's session note
            let description = !entry.userNote.isEmpty ? entry.userNote : entry.coachInsight
            if !description.isEmpty {
                Text(description)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Detailed skill breakdown
            let updates = parsedSkillUpdates
            if !updates.isEmpty {
                ForEach(updates, id: \.skill) { update in
                    HStack(spacing: AppSpacing.xxs) {
                        Text(update.skill)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(update.old)%")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(update.new)%")
                            .font(AppTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                }
            }

            // Duration
            if entry.durationMinutes > 0 {
                Label("\(entry.durationMinutes) min", systemImage: "clock")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Drills
            if entry.drillsCount > 0 {
                HStack(spacing: AppSpacing.xxs) {
                    Label("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") added",
                          systemImage: "figure.pickleball")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.coral)
                }
            }

            // Drill names
            if !entry.drillNamesSummary.isEmpty {
                Text(entry.drillNamesSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        TimelineView()
    }
}
