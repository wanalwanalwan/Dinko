import SwiftUI

struct DrillQueueView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: DrillQueueViewModel?
    @State private var expandedDrillId: UUID?
    @State private var historyExpanded = false

    var body: some View {
        Group {
            if let viewModel {
                drillContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Practice Queue")
        .task {
            if viewModel == nil {
                let vm = DrillQueueViewModel(
                    drillRepository: dependencies.drillRepository,
                    skillRepository: dependencies.skillRepository
                )
                viewModel = vm
                await vm.loadDrills()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadDrills() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func drillContent(_ viewModel: DrillQueueViewModel) -> some View {
        if viewModel.pendingDrills.isEmpty && viewModel.completedDrills.isEmpty {
            ContentUnavailableView(
                "No Drills Yet",
                systemImage: "figure.run",
                description: Text("Log a session with the Coach to get personalized drill recommendations.")
            )
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if !viewModel.pendingDrills.isEmpty {
                        summaryBanner(viewModel)
                        pendingSection(viewModel)
                    }

                    if !viewModel.completedDrills.isEmpty {
                        historySection(viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
            }
            .refreshable {
                await viewModel.loadDrills()
            }
        }
    }

    // MARK: - Summary Banner

    private func summaryBanner(_ viewModel: DrillQueueViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "figure.run")
                .font(.system(size: 16, weight: .semibold))

            Text("\(viewModel.pendingDrills.count) drill\(viewModel.pendingDrills.count == 1 ? "" : "s") queued")
                .font(AppTypography.headline)

            Text("\u{2022}")

            Text("~\(viewModel.totalEstimatedMinutes) min")
                .font(AppTypography.callout)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.teal)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Pending Drills

    private func pendingSection(_ viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.pendingDrills.enumerated()), id: \.element.id) { index, drill in
                if index > 0 {
                    Divider()
                }

                pendingDrillRow(drill, viewModel: viewModel)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    private func pendingDrillRow(_ drill: Drill, viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedDrillId = expandedDrillId == drill.id ? nil : drill.id
                }
            } label: {
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Image(systemName: drill.priorityIcon)
                        .foregroundStyle(drill.priorityColor)
                        .font(.system(size: 14))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(drill.name)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xxxs) {
                            Text("\(drill.durationMinutes) min")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            if let skillName = viewModel.skillNames[drill.skillId] {
                                Text("\u{2022}")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(skillName)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.teal)
                            }

                            if let subskill = drill.targetSubskill {
                                Text("\u{2022}")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(subskill)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: expandedDrillId == drill.id ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if expandedDrillId == drill.id {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(drill.drillDescription)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))

                    Text(drill.reason)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .italic()

                    HStack(spacing: AppSpacing.xs) {
                        if !drill.equipment.isEmpty {
                            Label(drill.equipment, systemImage: "wrench.and.screwdriver")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        if drill.playerCount > 1 {
                            Label("\(drill.playerCount) players", systemImage: "person.2")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            Task { await viewModel.markDone(drill.id) }
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.successGreen)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.successGreen)

                        Button {
                            Task { await viewModel.skip(drill.id) }
                        } label: {
                            Label("Skip", systemImage: "forward.fill")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, AppSpacing.xxxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - History

    private func historySection(_ viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(AppColors.teal)

                    Text("History")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("\(viewModel.completedDrills.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if historyExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    ForEach(viewModel.completedDrills) { drill in
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: drill.status == .completed ? "checkmark.circle.fill" : "forward.fill")
                                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                                .font(.system(size: 14))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(drill.name)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textPrimary)

                                Text(drill.updatedAt, style: .date)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            Spacer()

                            Text(drill.status == .completed ? "Done" : "Skipped")
                                .font(AppTypography.caption)
                                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary).opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, AppSpacing.xxxs)
                    }
                }
                .padding(.top, AppSpacing.xs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

#Preview {
    NavigationStack {
        DrillQueueView()
    }
}
