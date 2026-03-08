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

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Time + session type
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

            // Coach insight
            if !entry.coachInsight.isEmpty {
                Text(entry.coachInsight)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(3)
            }

            // Skill updates summary
            if !entry.skillUpdatesSummary.isEmpty {
                Text(entry.skillUpdatesSummary)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }

            // Stats row
            HStack(spacing: AppSpacing.sm) {
                if entry.skillUpdatesCount > 0 {
                    Label("\(entry.skillUpdatesCount) skill\(entry.skillUpdatesCount == 1 ? "" : "s") updated",
                          systemImage: "chart.line.uptrend.xyaxis")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.successGreen)
                }

                if entry.drillsCount > 0 {
                    Label("\(entry.drillsCount) drill\(entry.drillsCount == 1 ? "" : "s")",
                          systemImage: "figure.pickleball")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.coral)
                }
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
