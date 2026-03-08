import SwiftUI

struct JournalView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: JournalViewModel?

    var body: some View {
        Group {
            if let viewModel {
                journalContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = JournalViewModel(
                    journalEntryRepository: dependencies.journalEntryRepository
                )
                viewModel = vm
                await vm.loadEntries()
            }
        }
    }

    @ViewBuilder
    private func journalContent(_ viewModel: JournalViewModel) -> some View {
        if viewModel.dayGroups.isEmpty && !viewModel.isLoading {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.dayGroups) { group in
                        daySection(group, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
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

            Text("No Journal Entries Yet")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Log a session in the Coach tab and confirm it to create your first journal entry.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
    }

    private func daySection(_ group: JournalDayGroup, viewModel: JournalViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(group.displayDate)
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, AppSpacing.xxxs)

            ForEach(group.entries) { entry in
                JournalEntryCard(entry: entry)
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

// MARK: - Journal Entry Card

struct JournalEntryCard: View {
    let entry: JournalEntry

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: entry.date)
    }

    /// Parses "Skill|old|new|+delta" lines from skillUpdatesSummary
    private var parsedSkillUpdates: [(skill: String, old: String, new: String, delta: String)] {
        guard !entry.skillUpdatesSummary.isEmpty else { return [] }
        return entry.skillUpdatesSummary.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count == 4 else { return nil }
            return (skill: parts[0], old: parts[1], new: parts[2], delta: parts[3])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Time + session type + duration
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

                if entry.durationMinutes > 0 {
                    Label("\(entry.durationMinutes)m", systemImage: "clock")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            // User's session note
            if !entry.userNote.isEmpty {
                Text(entry.userNote)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
            }

            // Skill updates with percentage changes
            let updates = parsedSkillUpdates
            if !updates.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    ForEach(updates, id: \.skill) { update in
                        HStack(spacing: AppSpacing.xxs) {
                            Text(update.skill)
                                .font(AppTypography.callout)
                                .fontWeight(.medium)
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

                            Text(update.delta)
                                .font(AppTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(
                                    update.delta.hasPrefix("-") ? AppColors.coral : AppColors.successGreen
                                )
                        }
                    }
                }
            }

            // Drills count
            if entry.drillsCount > 0 {
                Label("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s") added",
                      systemImage: "figure.pickleball")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.coral)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
}
