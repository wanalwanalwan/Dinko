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
        .navigationBarTitleDisplayMode(.large)
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
                LazyVStack(spacing: AppSpacing.lg) {
                    ForEach(Array(viewModel.dayGroups.enumerated()), id: \.element.id) { index, group in
                        TimelineDaySection(group: group, viewModel: viewModel)
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

            ZStack {
                Circle()
                    .fill(AppColors.teal.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: "book.pages")
                    .font(.system(size: 40))
                    .foregroundStyle(AppColors.teal.opacity(0.6))
            }

            Text("No Sessions Yet")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Log a session with the Coach to start tracking your progress.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }
}

// MARK: - Day Section with Timeline Rail

struct TimelineDaySection: View {
    let group: TimelineDayGroup
    let viewModel: TimelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header
            Text(group.displayDate)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
                .padding(.leading, 28)
                .padding(.bottom, AppSpacing.xs)

            // Entries with vertical timeline rail
            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    // Timeline rail
                    VStack(spacing: 0) {
                        Circle()
                            .fill(hasSkillUpdates(entry) ? AppColors.teal : AppColors.teal.opacity(0.5))
                            .frame(width: 10, height: 10)
                            .padding(.top, 18)

                        if index < group.entries.count - 1 {
                            Rectangle()
                                .fill(AppColors.separator)
                                .frame(width: 2)
                        }
                    }
                    .frame(width: 16)

                    // Entry card
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

    private func hasSkillUpdates(_ entry: JournalEntry) -> Bool {
        !entry.skillUpdatesSummary.isEmpty
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

    private var parsedSkillUpdates: [SkillUpdateRow] {
        guard !entry.skillUpdatesSummary.isEmpty else { return [] }
        return entry.skillUpdatesSummary.components(separatedBy: "\n").compactMap { line in
            let pipeParts = line.components(separatedBy: "|")
            if pipeParts.count == 4 {
                let deltaVal = Int(pipeParts[3].replacingOccurrences(of: "+", with: "")) ?? 0
                return SkillUpdateRow(
                    skill: pipeParts[0],
                    oldValue: Int(pipeParts[1]) ?? 0,
                    newValue: Int(pipeParts[2]) ?? 0,
                    delta: deltaVal
                )
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
            let old = Int(arrowParts[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let newAndDelta = arrowParts[1].components(separatedBy: " ")
            let newVal = Int(newAndDelta[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let delta = newAndDelta.count >= 2 ? (Int(newAndDelta[1].trimmingCharacters(in: .whitespaces)) ?? 0) : 0
            return SkillUpdateRow(skill: skill, oldValue: old, newValue: newVal, delta: delta)
        }
    }

    var body: some View {
        Button {
            withAnimation(AppAnimations.springSmooth) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader
                    .padding(.bottom, AppSpacing.xs)

                let updates = parsedSkillUpdates
                if !updates.isEmpty {
                    skillMetricsSection(updates)
                } else if entry.drillsCount > 0 {
                    drillOnlyBadge
                }

                // Coach insight (special card look)
                if !entry.coachInsight.isEmpty {
                    coachInsightSection
                        .padding(.top, AppSpacing.xs)
                }

                // Expanded details
                if isExpanded {
                    expandedContent
                        .padding(.top, AppSpacing.xs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Expand hint
                HStack {
                    Spacer()
                    Text(isExpanded ? "Show Less" : "View Details")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.teal)
                }
                .padding(.top, AppSpacing.xs)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session at \(timeString), \(entry.skillUpdatesCount) skill updates")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand details")
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            HStack(alignment: .center) {
                // Session title
                Text("Practice Session")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                // Duration pill
                if entry.durationMinutes > 0 {
                    Label("\(entry.durationMinutes)m", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.teal.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: AppSpacing.xxs) {
                Text(timeString)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                if let sessionType = entry.sessionType, !sessionType.isEmpty {
                    Text("\u{00B7}")
                        .foregroundStyle(AppColors.textSecondary)
                    Text(sessionType.capitalized)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.drillPurple)
                }
            }
        }
    }

    // MARK: - Skill Metrics with Progress Bars

    private func skillMetricsSection(_ updates: [SkillUpdateRow]) -> some View {
        let displayUpdates = isExpanded ? updates : Array(updates.prefix(2))

        return VStack(spacing: AppSpacing.xs) {
            ForEach(displayUpdates, id: \.skill) { update in
                skillMetricRow(update)
            }

            if !isExpanded && updates.count > 2 {
                Text("+\(updates.count - 2) more skill\(updates.count - 2 == 1 ? "" : "s")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 28)
            }
        }
    }

    private func skillMetricRow(_ update: SkillUpdateRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: AppSpacing.xxs) {
                // Skill icon
                Text(iconForSkill(update.skill))
                    .font(.system(size: 14))

                Text(update.skill)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                // Percentage
                Text("\(update.newValue)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                // Delta indicator
                deltaIndicator(update.delta)

                // Micro feedback badge
                if update.delta >= 10 {
                    microBadge
                }
            }

            // Progress bar
            ProgressBar(
                progress: Double(update.newValue) / 100.0,
                tint: colorForDelta(update.delta)
            )
        }
    }

    private func deltaIndicator(_ delta: Int) -> some View {
        Group {
            if delta != 0 {
                HStack(spacing: 2) {
                    Image(systemName: delta > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((delta > 0 ? AppColors.successGreen : AppColors.coral).opacity(0.12))
                .clipShape(Capsule())
            } else {
                Text("--")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var microBadge: some View {
        Text("Personal Best")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.warningOrange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.warningOrange.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Drill-Only Badge

    private var drillOnlyBadge: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.coral)

            Text("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") added")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.coral)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppColors.coral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Coach Insight (Special Card)

    private var coachInsightSection: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.teal)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Coach Insight")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)

                Text(entry.coachInsight)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Divider()

            // User's session note
            if !entry.userNote.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SESSION NOTE")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(0.3)

                    Text(entry.userNote)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            // Detailed skill breakdown (old → new)
            let updates = parsedSkillUpdates
            if !updates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SKILL CHANGES")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(0.3)

                    ForEach(updates, id: \.skill) { update in
                        HStack(spacing: AppSpacing.xxs) {
                            Text(iconForSkill(update.skill))
                                .font(.system(size: 12))
                            Text(update.skill)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("\(update.oldValue)%")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                            Text("\(update.newValue)%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(colorForDelta(update.delta))
                        }
                    }
                }
            }

            // Drill names
            if !entry.drillNamesSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DRILLS ASSIGNED")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .tracking(0.3)

                    let drillNames = entry.drillNamesSummary.components(separatedBy: ", ")
                    ForEach(drillNames, id: \.self) { name in
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: "figure.pickleball")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.coral)
                            Text(name)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func iconForSkill(_ skillName: String) -> String {
        let lower = skillName.lowercased()
        if lower.contains("dink") { return "🥒" }
        if lower.contains("drop") { return "⬇️" }
        if lower.contains("drive") { return "🚀" }
        if lower.contains("defense") || lower.contains("block") { return "🛡️" }
        if lower.contains("offense") || lower.contains("attack") { return "🔥" }
        if lower.contains("strategy") || lower.contains("position") { return "♟️" }
        if lower.contains("serve") || lower.contains("return") { return "🎯" }
        if lower.contains("volley") { return "💥" }
        if lower.contains("lob") { return "🌈" }
        return "🏓"
    }

    private func colorForDelta(_ delta: Int) -> Color {
        if delta > 0 { return AppColors.successGreen }
        if delta < 0 { return AppColors.coral }
        return AppColors.textSecondary
    }
}

// MARK: - Skill Update Row Model

private struct SkillUpdateRow: Hashable {
    let skill: String
    let oldValue: Int
    let newValue: Int
    let delta: Int
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimelineView()
    }
}
