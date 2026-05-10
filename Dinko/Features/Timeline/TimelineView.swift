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
                            .frame(width: 8, height: 8)
                            .padding(.top, 16)

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

    private var skillUpdates: [SkillUpdateRow] {
        SkillUpdateRow.parseSkillUpdates(from: entry.skillUpdatesSummary)
    }

    var body: some View {
        Button {
            withAnimation(AppAnimations.springSmooth) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Row 1: Header
                let updates = skillUpdates
                let net = SkillUpdateRow.netChange(from: updates)
                headerRow(netChange: net, hasUpdates: !updates.isEmpty)

                // Row 2: Hero skill or drill badge
                if let hero = SkillUpdateRow.heroSkill(from: updates) {
                    heroSkillRow(hero)
                        .padding(.top, AppSpacing.xxs)
                } else if entry.drillsCount > 0 {
                    drillOnlyBadge
                        .padding(.top, AppSpacing.xxs)
                }

                // Row 3: Insight line (collapsed only shows single line)
                if !entry.coachInsight.isEmpty && !isExpanded {
                    insightLine
                        .padding(.top, AppSpacing.xxs)
                }

                // Expanded details
                if isExpanded {
                    expandedContent(updates)
                        .padding(.top, AppSpacing.xs)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
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

    // MARK: - Row 1: Header

    private func headerRow(netChange: Int, hasUpdates: Bool) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.xxs) {
            // Session type dot
            Circle()
                .fill(sessionTypeDotColor)
                .frame(width: 8, height: 8)

            // Time
            Text(timeString)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            // Session type label
            if let sessionType = entry.sessionType, !sessionType.isEmpty {
                Text(sessionType.capitalized)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            // Net change
            if hasUpdates && netChange != 0 {
                Text(netChange > 0 ? "+\(netChange)%" : "\(netChange)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(netChange > 0 ? AppColors.successGreen : AppColors.coral)
            }

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - Row 2: Hero Skill

    private func heroSkillRow(_ update: SkillUpdateRow) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Text(iconForSkill(update.skill))
                .font(.system(size: 13))

            Text(update.skill)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            // Mini progress bar
            ProgressBar(
                progress: Double(update.newValue) / 100.0,
                tint: colorForDelta(update.delta)
            )
            .frame(width: 48)

            // Current value
            Text("\(update.newValue)%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            // Delta indicator
            deltaIndicator(update.delta)
        }
    }

    // MARK: - Row 3: Insight Line

    private var insightLine: some View {
        Text(entry.coachInsight)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Expanded Content

    private func expandedContent(_ updates: [SkillUpdateRow]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Divider()

            // Session metadata
            sessionMetaRow

            // Full coach insight card
            if !entry.coachInsight.isEmpty {
                coachInsightCard
            }

            // All skill changes
            if !updates.isEmpty {
                skillChangesSection(updates)
            }

            // Session note
            if !entry.userNote.isEmpty {
                sessionNoteSection
            }

            // Drills
            if !entry.drillNamesSummary.isEmpty {
                drillsSection
            }
        }
    }

    // MARK: - Expanded: Session Meta

    private var sessionMetaRow: some View {
        HStack(spacing: AppSpacing.sm) {
            if entry.durationMinutes > 0 {
                Label("\(entry.durationMinutes) min", systemImage: "clock")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            if let sessionType = entry.sessionType, !sessionType.isEmpty {
                Label(sessionType.capitalized, systemImage: "figure.pickleball")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.drillPurple)
            }

            Spacer()
        }
    }

    // MARK: - Expanded: Coach Insight Card

    private var coachInsightCard: some View {
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
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.teal.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Expanded: Skill Changes

    private func skillChangesSection(_ updates: [SkillUpdateRow]) -> some View {
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

                    ProgressBar(
                        progress: Double(update.newValue) / 100.0,
                        tint: colorForDelta(update.delta)
                    )
                    .frame(width: 40)
                }
            }
        }
    }

    // MARK: - Expanded: Session Note

    private var sessionNoteSection: some View {
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

    // MARK: - Expanded: Drills

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DRILLS ASSIGNED")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.3)

            let drillNames = entry.drillNamesSummary.components(separatedBy: ", ")
            ForEach(drillNames, id: \.self) { name in
                HStack(spacing: AppSpacing.xxs) {
                    Image("coach-idle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                    Text(name)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
    }

    // MARK: - Drill-Only Badge

    private var drillOnlyBadge: some View {
        HStack(spacing: AppSpacing.xxs) {
            Image("coach-idle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)

            Text("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") added")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.coral)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppColors.coral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Shared Components

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

    // MARK: - Helpers

    private var sessionTypeDotColor: Color {
        guard let sessionType = entry.sessionType?.lowercased() else {
            return AppColors.teal
        }
        switch sessionType {
        case "drill", "drills":
            return AppColors.drillPurple
        case "match", "game":
            return AppColors.coral
        default:
            return AppColors.teal
        }
    }

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

// MARK: - Preview

#Preview {
    NavigationStack {
        TimelineView()
    }
}
