import SwiftUI

struct ProgramView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ProgramViewModel?
    @State private var showAllWeeks = false
    @State private var showPaywall = false
    @State private var showReplaceAlert = false
    @State private var showGenerationFlow = false
    @State private var pendingTemplate: ProgramTemplate?

    private var subscriptionService: SubscriptionService {
        dependencies.subscriptionService
    }

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
            viewModel?.loadTemplates()
            await viewModel?.loadProgram()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showGenerationFlow) {
            if let vm = viewModel {
                ProgramGenerationFlowView(viewModel: vm)
            }
        }
        .alert("Replace Current Program?", isPresented: $showReplaceAlert) {
            Button("Replace", role: .destructive) {
                if let template = pendingTemplate, let vm = viewModel {
                    Task { await vm.startCuratedProgram(template) }
                }
                pendingTemplate = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTemplate = nil
            }
        } message: {
            Text("Starting a new program will replace your current one. Your progress will be lost.")
        }
    }

    @ViewBuilder
    private func programContent(_ vm: ProgramViewModel) -> some View {
        if vm.isGenerating {
            generatingView
        } else {
            libraryView(vm)
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

    private func libraryView(_ vm: ProgramViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                // Active program section
                if let program = vm.activeProgram {
                    activeProgramSection(program, vm: vm)
                }

                // AI-Generated section
                aiGeneratedSection(vm)

                // Curated Programs section
                if !vm.templates.isEmpty {
                    curatedSection(vm)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }

                Spacer().frame(height: AppSpacing.xl)
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

    // MARK: - Active Program Section

    private func activeProgramSection(_ program: Program, vm: ProgramViewModel) -> some View {
        VStack(spacing: AppSpacing.sm) {
            ProgramHeaderCard(
                program: program,
                completedSessions: vm.completedSessionCount,
                totalSessions: program.totalSessions
            )

            // This Week section
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack {
                    Text("THIS WEEK")
                        .font(AppTypography.sectionLabel)
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.xxs)

                ForEach(vm.currentWeekSessions) { session in
                    let isPaywalled = session.weekNumber > 1 && !subscriptionService.isPro
                    if !isPaywalled && session.status == .available {
                        NavigationLink(value: session) {
                            WeekSessionCard(
                                session: session,
                                drillCount: vm.drillCounts[session.id] ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    } else if isPaywalled {
                        WeekSessionCard(
                            session: session,
                            drillCount: vm.drillCounts[session.id] ?? 0,
                            isPaywalled: true
                        )
                        .onTapGesture { showPaywall = true }
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
                            let weekPaywalled = weekNum > 1 && !subscriptionService.isPro

                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                HStack {
                                    Text("WEEK \(weekNum)")
                                        .font(AppTypography.sectionLabel)
                                        .tracking(0.8)
                                        .foregroundStyle(AppColors.textSecondary)
                                    if weekPaywalled {
                                        ProBadge(fontSize: 8)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.xxs)
                                .padding(.top, AppSpacing.xxs)

                                ForEach(weekSessions) { session in
                                    if weekPaywalled {
                                        WeekSessionCard(
                                            session: session,
                                            drillCount: vm.drillCounts[session.id] ?? 0,
                                            isPaywalled: true
                                        )
                                        .onTapGesture { showPaywall = true }
                                    } else {
                                        WeekSessionCard(
                                            session: session,
                                            drillCount: vm.drillCounts[session.id] ?? 0
                                        )
                                    }
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
        }
    }

    // MARK: - AI-Generated Section

    private func aiGeneratedSection(_ vm: ProgramViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if vm.activeProgram == nil {
                Text("AI-GENERATED")
                    .font(AppTypography.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.xxs)

                GenerateProgramCard {
                    showGenerationFlow = true
                }
            }
        }
    }

    // MARK: - Curated Section

    private func curatedSection(_ vm: ProgramViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("CURATED PROGRAMS")
                .font(AppTypography.sectionLabel)
                .tracking(0.8)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.top, AppSpacing.xs)

            ForEach(vm.templates) { template in
                ProgramTemplateCard(
                    template: template,
                    isPro: subscriptionService.isPro
                ) {
                    handleTemplateTap(template, vm: vm)
                }
            }
        }
    }

    // MARK: - Actions

    private func handleTemplateTap(_ template: ProgramTemplate, vm: ProgramViewModel) {
        // Pro-only template and user is free → paywall
        if template.isPremium && !subscriptionService.isPro {
            showPaywall = true
            return
        }

        // Has an active program → confirm replacement
        if vm.activeProgram != nil {
            pendingTemplate = template
            showReplaceAlert = true
            return
        }

        // No active program → start directly
        Task { await vm.startCuratedProgram(template) }
    }
}
