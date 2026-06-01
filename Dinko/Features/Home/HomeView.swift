import SwiftUI

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @Binding var selectedTab: Int
    @Binding var showSessionTypeSheet: Bool
    var refreshID: UUID = UUID()

    @State private var viewModel: HomeViewModel?
    @State private var contentReady = false
    @State private var showAddSkill = false
    @State private var showProfile = false
    @State private var showAllAchievements = false
    @State private var celebratingAchievement: Achievement?
    @State private var brineScoreExpanded = false

    @AppStorage("pkkl_has_seen_profile_prompt") private var hasSeenProfilePrompt = false
    @AppStorage("pkkl_first_name") private var storedFirstName = ""
    @State private var showNamePrompt = false
    @State private var namePromptFirst = ""
    @State private var namePromptLast = ""

    var body: some View {
        Group {
            if let viewModel {
                mainContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                let vm = HomeViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository,
                    sessionRepository: dependencies.sessionRepository,
                    journalEntryRepository: dependencies.journalEntryRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadDashboard()
            }
            if storedFirstName.isEmpty {
                showNamePrompt = true
            }
        }
        .sheet(isPresented: $showNamePrompt) {
            namePromptSheet
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadDashboard() }
            }
        }
        .onChange(of: refreshID) {
            if let viewModel {
                Task { await viewModel.loadDashboard() }
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
        .alert("Delete Account", isPresented: Binding(
            get: { authViewModel?.showDeleteConfirmation ?? false },
            set: { authViewModel?.showDeleteConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await authViewModel?.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account and all your data. This cannot be undone.")
        }
        .overlay {
            if authViewModel?.isDeletingAccount == true {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: AppSpacing.sm) {
                        ProgressView().scaleEffect(1.2)
                        Text("Deleting account…")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.lg)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .overlay {
            if let achievement = celebratingAchievement {
                AchievementCelebrationView(achievement: achievement) {
                    celebratingAchievement = nil
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeOut(duration: 0.25), value: celebratingAchievement?.id)
    }

    // MARK: - Main Content

    private func mainContent(_ viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection(viewModel)
                    .staggeredAppearance(index: 0)

                brineScoreCard(viewModel)
                    .staggeredAppearance(index: 1)

                if !viewModel.allOnboardingComplete {
                    gettingStartedSection(viewModel)
                        .staggeredAppearance(index: 2)
                }

                skillsSnapshotSection(viewModel)
                    .staggeredAppearance(index: 3)

                coachSection(viewModel)
                    .staggeredAppearance(index: 4)

                achievementsSection(viewModel)
                    .staggeredAppearance(index: 5)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xl + 60)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .background(homeBackground)
        .refreshable { await viewModel.loadDashboard() }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showAddSkill) {
            AddEditSkillView()
                .presentationDetents([.medium])
                .onDisappear { Task { await viewModel.loadDashboard() } }
        }
    }

    // MARK: - Background

    private var homeBackground: some View {
        ZStack {
            AppColors.backgroundGradient.ignoresSafeArea()
            RadialGradient(
                colors: [AppColors.primary.opacity(0.07), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private func headerSection(_ viewModel: HomeViewModel) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.greetingText + ",")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                Text(viewModel.playerName)
                    .font(Font.custom("Sora-Bold", size: 28))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            Button { showProfile = true } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppColors.primary.opacity(0.55))
            }
        }
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: - Brine Score Card

    private func brineScoreCard(_ viewModel: HomeViewModel) -> some View {
        let score   = viewModel.brineScore
        let color   = brineScoreColor(score)
        let goalMet = viewModel.thisWeekSessionCount >= viewModel.weeklySessionGoal

        return VStack(spacing: AppSpacing.sm) {

            // ── Top row ────────────────────────────────────────────────────
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                if goalMet {
                    Label("Goal met!", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.highlight)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColors.highlight.opacity(0.12))
                        .clipShape(Capsule())
                } else if viewModel.streakDays > 0 {
                    Label("\(viewModel.streakDays)-day streak", systemImage: "flame.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.warningOrange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(AppColors.warningOrange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // ── Gauge + Alma-style label floating in ring gap ──────────────
            ZStack(alignment: .bottom) {
                // Ring
                ZStack {
                    // Track
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(AppColors.ringTrack,
                                style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(135))

                    // Progress
                    Circle()
                        .trim(from: 0, to: max(CGFloat(score) / 100.0 * 0.75,
                                               score > 0 ? 0.015 : 0))
                        .stroke(
                            LinearGradient(colors: [color.opacity(0.8), color],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 13, lineCap: .round)
                        )
                        .rotationEffect(.degrees(135))
                        .animation(.easeOut(duration: 1.1), value: score)

                    // Score number — just the number, like Alma
                    Text("\(score)")
                        .font(Font.custom("Sora-Bold", size: 54))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                }
                .frame(width: 184, height: 184)

                // "Brine Score ›" pill — floats at bottom of ring in the gap
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                        brineScoreExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("Brine Score")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .rotationEffect(.degrees(brineScoreExpanded ? 90 : 0))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.cardBackground)
                            .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
                    )
                }
                .buttonStyle(.plain)
                .offset(y: 18) // float into the open gap at the bottom
            }
            .padding(.bottom, 22) // room for the floating label

            // ── Inline breakdown (expands from the label) ──────────────────
            if brineScoreExpanded {
                brineScoreBreakdown(viewModel)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                        removal:   .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                    ))
            }

            // ── Tagline ────────────────────────────────────────────────────
            Text(brineScoreLabel(score))
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            // ── Stats strip ────────────────────────────────────────────────
            Divider().padding(.top, 2)

            HStack(spacing: 0) {
                inlineStat(value: "\(viewModel.thisWeekSessionCount)",
                           label: "Sessions",
                           icon: "figure.pickleball",
                           color: AppColors.primary)
                inlineStatDivider
                inlineStat(value: viewModel.streakDays > 0 ? "\(viewModel.streakDays)" : "—",
                           label: "Day Streak",
                           icon: "flame.fill",
                           color: AppColors.warningOrange)
                inlineStatDivider
                inlineStat(value: viewModel.improvedSkillCount > 0 ? "\(viewModel.improvedSkillCount)" : "—",
                           label: "Improved",
                           icon: "arrow.up.right",
                           color: AppColors.highlight)
                inlineStatDivider
                inlineStat(value: viewModel.completedSkills.isEmpty ? "—" : "\(viewModel.completedSkills.count)",
                           label: "Completed",
                           icon: "checkmark.seal.fill",
                           color: AppColors.trophyGold)
            }
            .padding(.top, 4)

            // ── CTA — below stats so score story reads top to bottom ───────
            Divider()

            Button { showSessionTypeSheet = true } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text(viewModel.thisWeekSessionCount == 0 ? "Log First Session" : "Log Session")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        LinearGradient(
                            colors: [AppColors.primaryLight, AppColors.primaryDark],
                            startPoint: .top, endPoint: .bottom
                        )
                        // Gloss highlight — subtle white sheen at the top
                        LinearGradient(
                            colors: [.white.opacity(0.16), .clear],
                            startPoint: .top,
                            endPoint: .init(x: 0.5, y: 0.55)
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: AppColors.primary.opacity(0.30), radius: 0, y: 3)
                .shadow(color: AppColors.primary.opacity(0.14), radius: 8, y: 5)
            }
            .buttonStyle(.pressable)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 5)
    }

    private func brineScoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<35:  return AppColors.coral
        case 35..<55: return AppColors.warningOrange
        case 55..<75: return AppColors.highlight
        default:      return AppColors.successGreen
        }
    }

    private func brineScoreLabel(_ score: Int) -> String {
        switch score {
        case 0..<20:  return "Just getting started — every session counts."
        case 20..<40: return "Building the habit. Keep showing up."
        case 40..<55: return "Finding your rhythm. Good consistency."
        case 55..<70: return "Solid form. Your game is developing well."
        case 70..<85: return "Strong all around. You're dialing it in."
        case 85..<95: return "Elite consistency. Top of the court."
        default:      return "All-court weapon. You're the real dill. 🥒"
        }
    }

    // MARK: - Brine Score Inline Breakdown

    private func brineScoreBreakdown(_ viewModel: HomeViewModel) -> some View {
        let skillPts   = Int(Double(viewModel.averageRating) * 0.40)
        let streakPts  = Int(min(Double(viewModel.streakDays), 14.0) / 14.0 * 15.0)
        let sessionPts = viewModel.weeklySessionGoal > 0
            ? Int(min(Double(viewModel.thisWeekSessionCount), Double(viewModel.weeklySessionGoal)) / Double(viewModel.weeklySessionGoal) * 10.0)
            : 0
        let momentumPts = Int(min(Double(viewModel.improvedSkillCount) / Double(max(viewModel.totalActiveSkills, 1)), 1.0) * 20.0)
        var engagePts = 0
        if viewModel.totalActiveSkills > 0      { engagePts += 5 }
        if viewModel.totalSessionsAllTime > 0   { engagePts += 5 }
        if !viewModel.recommendedDrills.isEmpty { engagePts += 3 }
        if !viewModel.completedSkills.isEmpty   { engagePts += 2 }

        return VStack(spacing: 0) {
            Divider()

            VStack(spacing: 0) {
                scoreRow(icon: "chart.bar.fill",  color: AppColors.primary,
                         title: "Skill Level",    subtitle: "Average rating across all skills",
                         pts: skillPts,            maxPts: 40)
                Divider().padding(.leading, 52)
                scoreRow(icon: "flame.fill",       color: AppColors.warningOrange,
                         title: "Consistency",    subtitle: "Day streak + weekly session goal",
                         pts: streakPts + sessionPts, maxPts: 25)
                Divider().padding(.leading, 52)
                scoreRow(icon: "arrow.up.right",   color: AppColors.highlight,
                         title: "Momentum",       subtitle: "Skills improving this week",
                         pts: momentumPts,         maxPts: 20)
                Divider().padding(.leading, 52)
                scoreRow(icon: "sparkles",         color: AppColors.trophyGold,
                         title: "Engagement",     subtitle: "Using skills, drills & features",
                         pts: engagePts,           maxPts: 15)
            }

            Divider()

            Text("Updates each time you log a session or rate a skill.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
        }
    }

    private func scoreRow(icon: String, color: Color, title: String, subtitle: String, pts: Int, maxPts: Int) -> some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("\(pts) / \(maxPts)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.ringTrack).frame(height: 4)
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * (maxPts > 0 ? CGFloat(pts) / CGFloat(maxPts) : 0), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 14)
    }

    // MARK: - Getting Started Checklist

    private func gettingStartedSection(_ viewModel: HomeViewModel) -> some View {
        let completed = viewModel.onboardingStepsCompleted
        let remaining = 4 - completed

        return VStack(alignment: .leading, spacing: 0) {

            // ── Header ─────────────────────────────────────────────────────
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GETTING STARTED")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(remaining == 1 ? "1 step remaining" : "\(remaining) steps remaining")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i < completed ? AppColors.primary : AppColors.ringTrack)
                            .frame(width: 18, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: completed)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider()
                .padding(.horizontal, AppSpacing.sm)

            // ── Steps ──────────────────────────────────────────────────────
            VStack(spacing: 0) {
                checklistRow(
                    title: "Account Created",
                    icon: "person.fill",
                    isComplete: true,
                    isNext: false,
                    actionLabel: nil,
                    action: nil
                )
                checklistRow(
                    title: "Complete Profile",
                    icon: "slider.horizontal.3",
                    isComplete: viewModel.isProfileComplete,
                    isNext: !viewModel.isProfileComplete,
                    actionLabel: "Set up",
                    action: { showProfile = true }
                )
                checklistRow(
                    title: "Add First Skill",
                    icon: "target",
                    isComplete: viewModel.hasAnySkills,
                    isNext: viewModel.isProfileComplete && !viewModel.hasAnySkills,
                    actionLabel: "Add",
                    action: { showAddSkill = true }
                )
                checklistRow(
                    title: "Log First Session",
                    icon: "figure.pickleball",
                    isComplete: viewModel.hasLoggedAnySession,
                    isNext: viewModel.isProfileComplete && viewModel.hasAnySkills && !viewModel.hasLoggedAnySession,
                    actionLabel: "Log",
                    action: { showSessionTypeSheet = true }
                )
            }
            .padding(.bottom, AppSpacing.xxs)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private func checklistRow(
        title: String,
        icon: String,
        isComplete: Bool,
        isNext: Bool,
        actionLabel: String?,
        action: (() -> Void)?
    ) -> some View {
        HStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(isComplete
                          ? AppColors.highlight.opacity(0.14)
                          : isNext
                          ? AppColors.primary.opacity(0.1)
                          : AppColors.ringTrack.opacity(0.45))
                    .frame(width: 30, height: 30)
                Image(systemName: isComplete ? "checkmark" : icon)
                    .font(.system(size: isComplete ? 11 : 12, weight: .semibold))
                    .foregroundStyle(isComplete
                                     ? AppColors.highlight
                                     : isNext ? AppColors.primary : AppColors.lockedGray)
            }

            Text(title)
                .font(.system(size: 14,
                              weight: isNext ? .semibold : .regular,
                              design: .rounded))
                .foregroundStyle(isComplete ? AppColors.textSecondary : AppColors.textPrimary)
                .strikethrough(isComplete, color: AppColors.textSecondary.opacity(0.6))

            Spacer()

            if !isComplete, isNext, let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 11)
        .opacity(isComplete ? 0.65 : 1.0)
    }

    // MARK: - Inline stat helpers (used inside heroGoalCard)

    private func inlineStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(Font.custom("Sora-Bold", size: 18))
                .foregroundStyle(AppColors.textPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var inlineStatDivider: some View {
        Rectangle()
            .fill(AppColors.separator.opacity(0.5))
            .frame(width: 0.5)
            .padding(.vertical, 8)
    }

    // MARK: - Skills Snapshot

    private func skillsSnapshotSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeaderView(title: "Skills Snapshot", actionTitle: "See All") {
                selectedTab = 2
            }
            if viewModel.skillsWithRatings.isEmpty {
                skillsEmptyState
            } else {
                let cards = buildSpotlightCards(viewModel)
                VStack(spacing: AppSpacing.xxs) {
                    ForEach(cards, id: \.skill.id) { card in
                        spotlightCard(skill: card.skill, rating: card.rating)
                    }
                }
            }
        }
    }

    private var skillsEmptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(AppColors.primaryTint)
                    .frame(width: 54, height: 54)
                Image(systemName: "target")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(spacing: 5) {
                Text("Build your skill map")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Track the specific shots and skills\nthat make a great pickleball player.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            VStack(spacing: 6) {
                Text("Popular in pickleball:")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 6) {
                    ForEach(["🎯 Dinking", "🏓 Serve", "💨 Drive"], id: \.self) { name in
                        skillPill(name)
                    }
                }
                HStack(spacing: 6) {
                    ForEach(["🔄 Third Shot", "⚡️ Speed-Up", "📍 Volley"], id: \.self) { name in
                        skillPill(name)
                    }
                }
            }

            Button { showAddSkill = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add First Skill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.pressable)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private func skillPill(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(AppColors.primaryTint.opacity(0.7))
            .clipShape(Capsule())
    }

    // MARK: - Coach Section

    private func coachSection(_ viewModel: HomeViewModel) -> some View {
        Group {
            if !viewModel.hasLoggedAnySession {
                HStack(spacing: AppSpacing.xs) {
                    CoachMascot(state: .idle, size: 30)
                    Text("Log your first session to unlock personalized coaching insights.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.coachCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(AppColors.coachCardBorder.opacity(0.5), lineWidth: 0.5)
                )
            } else if viewModel.totalActiveSkills > 0 {
                HStack(spacing: AppSpacing.xs) {
                    CoachMascot(state: viewModel.mascotState, size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.coachingMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button { selectedTab = 2 } label: {
                            Text(viewModel.coachingActionLabel)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.primaryLight)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.coachCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                        .stroke(AppColors.coachCardBorder.opacity(0.5), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Achievements

    private func achievementsSection(_ viewModel: HomeViewModel) -> some View {
        let unlocked = viewModel.achievements.filter(\.isUnlocked)
        let locked   = viewModel.achievements.filter { !$0.isUnlocked }

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeaderView(title: "Badges", actionTitle: "See All") {
                showAllAchievements = true
            }

            Text("\(unlocked.count) of \(viewModel.achievements.count) earned")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(unlocked.reversed(), id: \.achievement.id) { item in
                        AchievementBadge(name: item.achievement.name,
                                         iconName: item.achievement.iconName,
                                         isUnlocked: true,
                                         badgeColor: item.achievement.color)
                    }
                    ForEach(locked.prefix(4), id: \.achievement.id) { item in
                        AchievementBadge(name: item.achievement.name,
                                         iconName: item.achievement.iconName,
                                         isUnlocked: false,
                                         badgeColor: item.achievement.color)
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }

            if let newest = viewModel.newlyUnlockedAchievements.first, celebratingAchievement == nil {
                Color.clear.onAppear { celebratingAchievement = newest }
            }
        }
        .sheet(isPresented: $showAllAchievements) { allAchievementsSheet(viewModel) }
    }

    // MARK: - Spotlight Cards (data state)

    private struct SpotlightItem {
        let skill: Skill; let rating: Int
    }

    private func buildSpotlightCards(_ viewModel: HomeViewModel) -> [SpotlightItem] {
        var cards: [SpotlightItem] = []
        var used: Set<UUID> = []

        if let weak = viewModel.weakestSkill {
            cards.append(.init(skill: weak.skill, rating: weak.rating))
            used.insert(weak.skill.id)
        }
        if let focus = viewModel.focusSkill, !used.contains(focus.skill.id) {
            cards.append(.init(skill: focus.skill, rating: focus.rating))
            used.insert(focus.skill.id)
        }
        if let strong = viewModel.strongestSkill, !used.contains(strong.skill.id) {
            cards.append(.init(skill: strong.skill, rating: strong.rating))
            used.insert(strong.skill.id)
        }
        if cards.count < 3 {
            for item in viewModel.skillsWithRatings where !used.contains(item.skill.id) {
                cards.append(.init(skill: item.skill, rating: item.rating))
                used.insert(item.skill.id)
                if cards.count >= 3 { break }
            }
        }
        return Array(cards.prefix(3))
    }

    private func spotlightCard(skill: Skill, rating: Int) -> some View {
        let tier = SkillTier(rating: rating)
        return HStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle().fill(tier.color.opacity(0.1)).frame(width: 34, height: 34)
                Text(skill.iconName).font(.system(size: 15))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                ProgressBar(progress: Double(rating) / 100.0, tint: tier.color)
            }
            Text("\(rating)%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }

    private func allAchievementsSheet(_ viewModel: HomeViewModel) -> some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: AppSpacing.sm)],
                          spacing: AppSpacing.md) {
                    ForEach(viewModel.achievements, id: \.achievement.id) { item in
                        VStack(spacing: AppSpacing.xxs) {
                            AchievementBadge(name: item.achievement.name,
                                             iconName: item.achievement.iconName,
                                             isUnlocked: item.isUnlocked,
                                             badgeColor: item.achievement.color)
                            Text(item.achievement.description)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(item.isUnlocked ? AppColors.textSecondary : AppColors.lockedGray)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColors.backgroundGradient)
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAllAchievements = false }
                }
            }
        }
    }

    // MARK: - Name Prompt Sheet

    private var namePromptSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            CoachMascot(state: .idle, size: 64, animated: true)

            VStack(spacing: AppSpacing.xxs) {
                Text("What's your name?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("We'll use it to personalize your experience.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: AppSpacing.xs) {
                TextField("First Name", text: $namePromptFirst)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.xs)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Last Name", text: $namePromptLast)
                    .textContentType(.familyName)
                    .autocorrectionDisabled()
                    .padding(AppSpacing.xs)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, AppSpacing.lg)

            Button {
                let first = namePromptFirst.trimmingCharacters(in: .whitespacesAndNewlines)
                let last  = namePromptLast.trimmingCharacters(in: .whitespacesAndNewlines)
                if !first.isEmpty {
                    storedFirstName = first
                    UserDefaults.standard.set(last, forKey: "pkkl_last_name")
                    if let vm = viewModel { Task { await vm.loadDashboard() } }
                }
                showNamePrompt = false
            } label: {
                Text(namePromptFirst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Skip" : "Continue")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(namePromptFirst.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AppColors.textSecondary.opacity(0.5)
                                : AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
        }
        .background(AppColors.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Achievement Celebration

private struct AchievementCelebrationView: View {
    let achievement: Achievement
    let onDismiss: () -> Void

    // Whole-overlay fade (controls the blur backdrop + all content together)
    @State private var overlayOpacity: Double = 1

    // Badge entry
    @State private var badgeScale: CGFloat    = 0.05
    @State private var badgeRotation: Double  = -18
    @State private var badgeOpacity: Double   = 0

    // Text block
    @State private var textOpacity: Double    = 0
    @State private var textOffset: CGFloat    = 22

    // Expanding ring pulses
    @State private var r1Scale: CGFloat = 1.0;  @State private var r1Opacity: Double = 0.55
    @State private var r2Scale: CGFloat = 1.0;  @State private var r2Opacity: Double = 0.40
    @State private var r3Scale: CGFloat = 1.0;  @State private var r3Opacity: Double = 0.28

    // Glow behind badge
    @State private var glowScale: CGFloat     = 0.7
    @State private var glowOpacity: Double    = 0.7

    var body: some View {
        ZStack {
            // ── Blurred backdrop ──────────────────────────────────────────
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 30) {
                // ── Badge ─────────────────────────────────────────────────
                ZStack {
                    // Ring pulses
                    pulseRing(scale: r1Scale, opacity: r1Opacity)
                    pulseRing(scale: r2Scale, opacity: r2Opacity)
                    pulseRing(scale: r3Scale, opacity: r3Opacity)

                    // Colored glow disc
                    RoundedRectangle(cornerRadius: 32)
                        .fill(achievement.color.opacity(glowOpacity))
                        .frame(width: 148, height: 148)
                        .blur(radius: 28)
                        .scaleEffect(glowScale)

                    // Badge tile
                    RoundedRectangle(cornerRadius: 28)
                        .fill(achievement.color)
                        .frame(width: 112, height: 112)
                        .overlay(
                            Image(systemName: achievement.iconName)
                                .font(.system(size: 50, weight: .medium))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: achievement.color.opacity(0.55), radius: 30, y: 12)
                        .shadow(color: achievement.color.opacity(0.20), radius: 60, y: 24)
                        .scaleEffect(badgeScale)
                        .rotationEffect(.degrees(badgeRotation))
                        .opacity(badgeOpacity)
                }

                // ── Text ──────────────────────────────────────────────────
                VStack(spacing: 7) {
                    Text("Badge Earned!")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(achievement.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(achievement.color)

                    Text(achievement.description)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Text("Tap anywhere to continue")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.55))
                        .padding(.top, 10)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .opacity(overlayOpacity)
        .onAppear { runEntryAnimation() }
    }

    private func pulseRing(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .stroke(achievement.color.opacity(opacity), lineWidth: 1.5)
            .frame(width: 148, height: 148)
            .scaleEffect(scale)
    }

    // MARK: Entry animation
    private func runEntryAnimation() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Badge springs in
        withAnimation(.spring(response: 0.52, dampingFraction: 0.60)) {
            badgeScale    = 1.0
            badgeRotation = 0
            badgeOpacity  = 1
        }

        // Glow expands + fades
        withAnimation(.easeOut(duration: 1.0)) {
            glowScale   = 1.6
            glowOpacity = 0
        }

        // Ring 1 — immediate
        withAnimation(.easeOut(duration: 1.15)) {
            r1Scale = 2.4; r1Opacity = 0
        }
        // Ring 2 — slight delay
        withAnimation(.easeOut(duration: 1.15).delay(0.16)) {
            r2Scale = 2.4; r2Opacity = 0
        }
        // Ring 3 — longer delay
        withAnimation(.easeOut(duration: 1.15).delay(0.32)) {
            r3Scale = 2.4; r3Opacity = 0
        }

        // Text rises in
        withAnimation(.spring(response: 0.48, dampingFraction: 0.78).delay(0.22)) {
            textOpacity = 1
            textOffset  = 0
        }
    }

    // MARK: Dismiss animation
    private func dismiss() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
            badgeScale   = 0.05
            badgeOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.22)) {
            textOpacity = 0
        }
        // Fade the entire overlay (including the blur backdrop) so it never sticks.
        // Then remove the view inside withAnimation so the parent's transition fires
        // correctly — calling onDismiss() bare from a DispatchQueue block gave no
        // animation context, causing the blur to sometimes linger.
        withAnimation(.easeOut(duration: 0.28)) {
            overlayOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation { onDismiss() }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0), showSessionTypeSheet: .constant(false), refreshID: UUID())
    }
}
