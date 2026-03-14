import SwiftUI

struct DrillQueueView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: DrillQueueViewModel?
    @State private var historyExpanded = false
    @State private var contentReady = false

    var body: some View {
        Group {
            if let viewModel {
                drillContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Practice Queue")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let vm = DrillQueueViewModel(
                    drillRepository: dependencies.drillRepository,
                    skillRepository: dependencies.skillRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
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
                    // Hero card for first pending drill
                    if let firstDrill = viewModel.pendingDrills.first {
                        NavigationLink {
                            DrillDetailView(
                                drill: firstDrill,
                                skillName: viewModel.skillNames[firstDrill.skillId] ?? "Skill",
                                onComplete: { await viewModel.doRep(firstDrill.id) },
                                onSkip: { await viewModel.skip(firstDrill.id) }
                            )
                        } label: {
                            HeroDrillCard(
                                drill: firstDrill,
                                skillName: viewModel.skillNames[firstDrill.skillId],
                                totalCompleted: viewModel.totalDrillsCompleted
                            )
                        }
                        .buttonStyle(.pressable)
                        .staggeredAppearance(index: 0)
                    }

                    // Training summary
                    if !viewModel.pendingDrills.isEmpty {
                        TrainingSummaryCard(
                            pendingCount: viewModel.pendingDrills.count,
                            totalMinutes: viewModel.totalEstimatedMinutes,
                            focusSkill: viewModel.focusSkillName,
                            completedCount: viewModel.completedTodayCount,
                            progress: viewModel.sessionProgress,
                            totalCompleted: viewModel.totalDrillsCompleted
                        )
                        .staggeredAppearance(index: 1)
                    }

                    // Progression path for remaining drills
                    if viewModel.pendingDrills.count > 1 {
                        DrillProgressionPath(
                            drills: Array(viewModel.pendingDrills.dropFirst()),
                            skillNames: viewModel.skillNames,
                            onComplete: { drillId in await viewModel.doRep(drillId) },
                            onSkip: { drillId in await viewModel.skip(drillId) }
                        )
                        .staggeredAppearance(index: 2)
                    }

                    // History section
                    if !viewModel.completedDrills.isEmpty {
                        historyCard(viewModel)
                            .staggeredAppearance(index: 3)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xl)
                .contentLoadTransition(isLoaded: contentReady)
                .animation(AppAnimations.springSmooth, value: viewModel.pendingDrills.count)
            }
            .refreshable {
                await viewModel.loadDrills()
            }
        }
    }

    // MARK: - History Card

    private func historyCard(_ viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(AppAnimations.springSmooth) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.teal)

                    Text("History")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("\(viewModel.completedDrills.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.textSecondary.opacity(0.1))
                        .clipShape(Capsule())

                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if historyExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.completedDrills) { drill in
                        historyDrillRow(drill)
                    }
                }
                .padding(.top, AppSpacing.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }

    private func historyDrillRow(_ drill: Drill) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: drill.status == .completed ? "checkmark.circle.fill" : "forward.fill")
                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(drill.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text(drill.updatedAt, style: .date)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text(drill.status == .completed ? "Done" : "Skipped")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, AppSpacing.xxs)
        .frame(minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        DrillQueueView()
    }
}
