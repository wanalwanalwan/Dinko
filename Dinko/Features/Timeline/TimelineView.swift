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
                LazyVStack(spacing: AppSpacing.sm) {
                    ForEach(Array(viewModel.dayGroups.enumerated()), id: \.element.id) { index, group in
                        TimelineDayCard(group: group, viewModel: viewModel)
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

// MARK: - Day Card (groups all sessions under one date card)

struct TimelineDayCard: View {
    let group: TimelineDayGroup
    let viewModel: TimelineViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header inside the card
            Text(group.displayDate)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

            // Session rows
            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                TimelineSessionRow(entry: entry, viewModel: viewModel)

                if index < group.entries.count - 1 {
                    Divider()
                        .padding(.horizontal, AppSpacing.sm)
                }
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Session Row (collapsed = one line, expanded = TLDR)

struct TimelineSessionRow: View {
    let entry: JournalEntry
    let viewModel: TimelineViewModel
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
                // Collapsed: single clean row
                collapsedRow

                // Expanded: TLDR
                if isExpanded {
                    tldrSection
                        .padding(.top, AppSpacing.xs)
                        .transition(.scale(scale: 0.97, anchor: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.deleteEntry(entry.id) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session at \(timeString), \(entry.skillUpdatesCount) skill updates")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand details")
    }

    // MARK: - Collapsed Row

    private var collapsedRow: some View {
        let updates = skillUpdates
        let net = SkillUpdateRow.netChange(from: updates)

        return HStack(spacing: AppSpacing.xxs) {
            Text(timeString)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            if !updates.isEmpty {
                Text("\u{00B7}")
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(updates.count) skill\(updates.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }

            if net != 0 {
                Text(net > 0 ? "+\(net)%" : "\(net)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(net > 0 ? AppColors.successGreen : AppColors.coral)
            }

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    // MARK: - TLDR Section

    private var tldrSection: some View {
        Text(buildSummary())
            .font(.system(size: 14, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.xs)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Summary Builder

    private func buildSummary() -> String {
        let updates = skillUpdates
        let improved = updates.filter { $0.delta > 0 }
        let declined = updates.filter { $0.delta < 0 }
        let skillNames = Set(updates.map { $0.skill.lowercased() })

        var parts: [String] = []

        // Part 1: What changed
        if !improved.isEmpty {
            let names = improved.prefix(3).map { $0.skill }
            let avgGain = improved.reduce(0) { $0 + $1.delta } / improved.count
            parts.append("Improved \(names.joined(separator: ", ")) (+\(avgGain)% avg)")
        }
        if !declined.isEmpty {
            let names = declined.map { $0.skill }
            parts.append("\(names.joined(separator: ", ")) dipped")
        }

        // Part 2: Actionable tip from coach — skip if it just restates skill names
        if !entry.coachInsight.isEmpty {
            let sentences = entry.coachInsight
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Find a sentence that doesn't just repeat the skill names
            let actionWords = ["try", "focus", "practice", "work on", "keep", "use",
                               "improve", "start", "avoid", "remember", "make sure",
                               "drill", "aim", "slow", "stay", "add", "increase"]
            let tip = sentences.first { sentence in
                let lower = sentence.lowercased()
                let repeatsSkill = skillNames.contains { lower.hasPrefix($0) || lower == $0 }
                let hasAction = actionWords.contains { lower.contains($0) }
                return !repeatsSkill && (hasAction || sentences.count == 1)
            } ?? sentences.last(where: { sentence in
                let lower = sentence.lowercased()
                return !skillNames.contains { lower.hasPrefix($0) }
            })

            if let tip, !tip.isEmpty {
                let short = tip.count > 80 ? String(tip.prefix(80)) + "..." : tip
                parts.append(short)
            }
        }

        // Part 3: Fall back to user note if nothing else
        if parts.isEmpty {
            if !entry.userNote.isEmpty {
                let note = entry.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
                let short = note.count > 80 ? String(note.prefix(80)) + "..." : note
                parts.append(short)
            } else if entry.drillsCount > 0 {
                parts.append("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") assigned")
            }
        }

        if parts.isEmpty { return "Logged a session." }

        var summary = parts.joined(separator: ". ")
        if !summary.hasSuffix(".") { summary += "." }
        return summary
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimelineView()
    }
}
