import SwiftUI

struct TodayView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel = TodayViewModel()
    @State private var showSessionTypeSheet = false
    @State private var showSessionForm = false
    @State private var selectedSessionType: SessionType = .game
    @State private var showMilestoneAdjust = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    greetingHeader
                    focusSection
                    milestoneSuggestionSection
                    staleCheckInSection
                    weekStripSection
                    roadToGoalSection
                    coachInsightSection
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, 80) // space for FAB
            }
            .background(AppColors.backgroundGradient.ignoresSafeArea())
            .refreshable {
                await viewModel.loadToday()
            }

            quickLogFAB
        }
        .task {
            viewModel.skillRepository = dependencies.skillRepository
            viewModel.confidenceEntryRepository = dependencies.confidenceEntryRepository
            viewModel.focusHistoryRepository = dependencies.focusHistoryRepository
            viewModel.sessionRepository = dependencies.sessionRepository
            await viewModel.loadToday()
        }
        .sheet(isPresented: $showSessionTypeSheet) {
            SessionTypeSheet { type in
                selectedSessionType = type
                showSessionTypeSheet = false
                showSessionForm = true
            }
        }
        .sheet(isPresented: $showSessionForm, onDismiss: {
            Task { await viewModel.loadToday() }
        }) {
            let vm = LogSessionViewModel(
                skillRepository: dependencies.skillRepository,
                sessionRepository: dependencies.sessionRepository,
                journalEntryRepository: dependencies.journalEntryRepository,
                skillRatingRepository: dependencies.skillRatingRepository,
                drillRepository: dependencies.drillRepository,
                confidenceEntryRepository: dependencies.confidenceEntryRepository
            )
            LogSessionView(
                viewModel: {
                    vm.sessionType = selectedSessionType
                    // Pass focus skill for post-session check-in
                    if let focus = viewModel.todaysFocus {
                        vm.focusSkillId = focus.skill.id
                        vm.focusSkillName = focus.skill.name
                    }
                    return vm
                }()
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text(dateText)
                    .font(AppTypography.cardCaption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()

            if viewModel.streakDays > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppColors.coral)
                    Text("\(viewModel.streakDays)")
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.vertical, AppSpacing.xxxs)
                .background(AppColors.cardBackground)
                .clipShape(Capsule())
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Focus Section

    @ViewBuilder
    private var focusSection: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if let focus = viewModel.todaysFocus {
            FocusHeroCard(
                focus: focus,
                onStart: {
                    // Phase 1: just log session for now
                    selectedSessionType = focus.sessionType.isMasteryType ? .drill : focus.sessionType
                    showSessionForm = true
                },
                onNotToday: {
                    // TODO: Phase 2 - skip tracking
                },
                onSwap: {
                    viewModel.swapFocus()
                }
            )
        } else if !viewModel.goalDUPR.isEmpty {
            emptyFocusCard
        }
    }

    private var emptyFocusCard: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.successGreen)

            Text("All caught up!")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("All your skills are at or above your target for \(viewModel.goalDUPR) DUPR.")
                .font(AppTypography.cardBody)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .neumorphicRaised(intensity: .prominent)
    }

    // MARK: - Milestone Suggestion

    @ViewBuilder
    private var milestoneSuggestionSection: some View {
        if let suggestion = viewModel.milestoneSuggestion {
            MilestoneSuggestionCard(
                suggestion: suggestion,
                onAccept: {
                    Task { await viewModel.acceptMilestoneSuggestion() }
                },
                onAdjust: {
                    showMilestoneAdjust = true
                },
                onKeep: {
                    viewModel.dismissMilestoneSuggestion()
                }
            )
            .sheet(isPresented: $showMilestoneAdjust) {
                ConfidenceUpdateSheet(
                    skillName: suggestion.skillName,
                    currentConfidence: suggestion.currentConfidence,
                    onSave: { newValue in
                        let entry = ConfidenceEntry(
                            skillId: suggestion.skillId,
                            confidence: newValue,
                            source: .checkIn
                        )
                        Task {
                            try? await dependencies.confidenceEntryRepository.save(entry)
                            viewModel.dismissMilestoneSuggestion()
                        }
                    }
                )
            }
        }
    }

    // MARK: - Stale Check-Ins

    @ViewBuilder
    private var staleCheckInSection: some View {
        if let stale = viewModel.staleCheckIns.first {
            StaleCheckInCard(
                skillName: stale.skillName,
                lastConfidence: stale.confidence,
                onResponse: { response in
                    Task {
                        await viewModel.handleStaleCheckIn(
                            skillId: stale.skillId,
                            response: response
                        )
                    }
                }
            )
        }
    }

    // MARK: - Week Strip

    @ViewBuilder
    private var weekStripSection: some View {
        if let plan = viewModel.weekPlan {
            WeekScheduleStrip(
                weekPlan: plan,
                todayDayOfWeek: SchedulingEngine.todayDayOfWeek()
            )
        }
    }

    // MARK: - Road to Goal

    @ViewBuilder
    private var roadToGoalSection: some View {
        if viewModel.totalTrackableSkills > 0 {
            RoadToGoalBar(
                skillsAtTarget: viewModel.skillsAtTarget,
                totalSkills: viewModel.totalTrackableSkills,
                goalDUPR: viewModel.goalDUPR
            )
        }
    }

    // MARK: - Coach Insight

    @ViewBuilder
    private var coachInsightSection: some View {
        if !viewModel.coachInsightText.isEmpty {
            CoachInsightCard(text: viewModel.coachInsightText)
        }
    }

    // MARK: - Quick Log FAB

    private var quickLogFAB: some View {
        Button(action: {
            showSessionTypeSheet = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AppColors.primary)
                .clipShape(Circle())
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}
