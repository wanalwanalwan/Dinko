import SwiftUI

struct ProgramView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ProgramViewModel?
    @State private var showAllWeeks = false

    var body: some View {
        Group {
            if let vm = viewModel {
                programContent(vm)
            } else {
                ProgressView()
            }
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let vm = ProgramViewModel(
                    programRepository: dependencies.programRepository,
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository
                )
                viewModel = vm
            }
            await viewModel?.loadProgram()
        }
    }

    @ViewBuilder
    private func programContent(_ vm: ProgramViewModel) -> some View {
        if vm.isGenerating {
            generatingView
        } else if let program = vm.activeProgram {
            activeProgramView(program, vm: vm)
        } else {
            emptyStateView(vm)
        }
    }

    private var generatingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)

            Text("Building your program...")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("The AI coach is creating a personalized training plan based on your skills and goals.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
    }

    private func emptyStateView(_ vm: ProgramViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                Spacer().frame(height: AppSpacing.xl)

                GenerateProgramCard {
                    Task { await vm.generateProgram() }
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
        }
    }

    private func activeProgramView(_ program: Program, vm: ProgramViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                ProgramHeaderCard(
                    program: program,
                    completedSessions: vm.completedSessionCount,
                    totalSessions: program.totalSessions
                )

                // This Week section
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("THIS WEEK")
                        .font(AppTypography.sectionLabel)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.xxs)

                    ForEach(vm.currentWeekSessions) { session in
                        if session.status == .available {
                            NavigationLink(value: session) {
                                WeekSessionCard(
                                    session: session,
                                    drillCount: vm.drillCounts[session.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            WeekSessionCard(
                                session: session,
                                drillCount: vm.drillCounts[session.id] ?? 0
                            )
                        }
                    }
                }

                // All Weeks section
                if !vm.otherWeekSessions.isEmpty {
                    DisclosureGroup(isExpanded: $showAllWeeks) {
                        ForEach(vm.otherWeekSessions, id: \.first?.weekNumber) { weekSessions in
                            if let weekNum = weekSessions.first?.weekNumber {
                                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                    Text("WEEK \(weekNum)")
                                        .font(AppTypography.sectionLabel)
                                        .tracking(0.8)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .padding(.horizontal, AppSpacing.xxs)
                                        .padding(.top, AppSpacing.xxs)

                                    ForEach(weekSessions) { session in
                                        WeekSessionCard(
                                            session: session,
                                            drillCount: vm.drillCounts[session.id] ?? 0
                                        )
                                    }
                                }
                            }
                        }
                    } label: {
                        Text("All Weeks")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                    }
                    .tint(AppColors.primary)
                }

                // Delete program option
                Button(role: .destructive) {
                    Task { await vm.deleteProgram() }
                } label: {
                    Text("Delete Program")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                }
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.sm)
        }
        .navigationDestination(for: ProgramSession.self) { session in
            ProgramSessionDetailView(
                session: session,
                programRepository: dependencies.programRepository,
                onSessionComplete: {
                    Task { await vm.loadProgram() }
                }
            )
        }
    }
}
