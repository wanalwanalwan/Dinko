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

    private var sessionTypeLabel: String {
        entry.sessionType?.capitalized ?? "Session"
    }

    private var sessionTypeColor: Color {
        guard let type = entry.sessionType?.lowercased() else { return AppColors.teal }
        switch type {
        case "drill", "drills": return AppColors.drillPurple
        case "match", "game": return AppColors.coral
        default: return AppColors.teal
        }
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
        HStack(spacing: AppSpacing.xxs) {
            // Type dot
            Circle()
                .fill(sessionTypeColor)
                .frame(width: 8, height: 8)

            // Time
            Text(timeString)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Spacer()

            // Quick stat pills
            let updates = skillUpdates
            let net = SkillUpdateRow.netChange(from: updates)

            if !updates.isEmpty {
                Text("\(updates.count) skill\(updates.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.teal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.teal.opacity(0.1))
                    .clipShape(Capsule())
            }

            if net != 0 {
                Text(net > 0 ? "+\(net)%" : "\(net)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(net > 0 ? AppColors.successGreen : AppColors.coral)
            }

            // Chevron
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

        // Build a short synthesized summary from all available data
        var what: [String] = []
        var takeaway = ""

        // What happened — synthesize skills + user note into one thought
        if !improved.isEmpty {
            let names = improved.prefix(3).map { $0.skill }
            let joined = names.joined(separator: ", ")
            let avgGain = improved.reduce(0) { $0 + $1.delta } / improved.count
            what.append("Worked on \(joined) (+\(avgGain)% avg)")
        }

        if !declined.isEmpty {
            let names = declined.map { $0.skill }
            what.append("\(names.joined(separator: ", ")) needs work")
        }

        if what.isEmpty {
            // Fall back to user note or drills for context
            if !entry.userNote.isEmpty {
                let note = entry.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
                // Extract first sentence or first 80 chars as the "what"
                let firstSentence = note.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? note
                let short = firstSentence.count > 80 ? String(firstSentence.prefix(80)) + "..." : firstSentence
                what.append(short)
            } else if entry.drillsCount > 0 {
                what.append("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") assigned")
            }
        }

        // Takeaway — synthesize coach insight + user note into one action item
        if !entry.coachInsight.isEmpty {
            let insight = entry.coachInsight.trimmingCharacters(in: .whitespacesAndNewlines)
            // Grab just the first sentence as the key takeaway
            let firstSentence = insight.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).first ?? insight
            takeaway = firstSentence.trimmingCharacters(in: .whitespaces)
            if !takeaway.isEmpty && !takeaway.hasSuffix(".") {
                takeaway += "."
            }
        } else if !entry.userNote.isEmpty && !what.isEmpty {
            // If we already used skills for "what", pull a short note as takeaway
            let note = entry.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
            if note.count <= 60 {
                takeaway = note
                if !takeaway.hasSuffix(".") { takeaway += "." }
            }
        }

        // Combine into one short summary
        var summary = what.joined(separator: "; ")
        if !summary.isEmpty && !summary.hasSuffix(".") { summary += "." }
        if !takeaway.isEmpty {
            summary += summary.isEmpty ? takeaway : " \(takeaway)"
        }

        return summary.isEmpty ? "Logged a session." : summary
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TimelineView()
    }
}
