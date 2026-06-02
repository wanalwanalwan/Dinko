import SwiftUI
import Charts

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
    @State private var duprService = DUPRService.shared
    @State private var showDUPRStats = false
    @State private var focusManager = FocusSkillManager.shared
    @State private var showFocusPicker = false
    @State private var focusSkillPage = 0
    @State private var showAddIdeaSheet = false
    @State private var newIdeaName = ""
    @State private var newIdeaNotes = ""
    @State private var expandedIdeaId: UUID? = nil

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

                weeklySkillSwipeCard(viewModel)
                    .staggeredAppearance(index: 1)

                weeklyScheduleCard(viewModel)
                    .staggeredAppearance(index: 2)

                duprRatingCard
                    .staggeredAppearance(index: 3)

                weeklyStatsCard(viewModel)
                    .staggeredAppearance(index: 4)

                brineScoreCard(viewModel)
                    .staggeredAppearance(index: 5)

                achievementsSection(viewModel)
                    .staggeredAppearance(index: 6)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xl + 60)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .background(homeBackground)
        .refreshable { await viewModel.loadDashboard() }
        .sheet(isPresented: $showProfile) { ProfileView() }
        .sheet(isPresented: $showDUPRStats) { DUPRStatsView() }
        .sheet(isPresented: $showFocusPicker) {
            FocusSkillPickerSheet(existingSkills: viewModel.skillsWithRatings) { entries in
                focusManager.setFocusSkills(entries)
                Task {
                    let existingIds = viewModel.skillsWithRatings.map(\.skill.id)
                    for entry in entries where !existingIds.contains(entry.id) {
                        let skill = Skill(id: entry.id, name: entry.name, iconName: entry.icon)
                        try? await dependencies.skillRepository.save(skill)
                    }
                    await viewModel.loadDashboard()
                }
            }
        }
        .sheet(isPresented: $showAddSkill) {
            AddEditSkillView()
                .presentationDetents([.medium])
                .onDisappear { Task { await viewModel.loadDashboard() } }
        }
    }

    // MARK: - Weekly Plan Card

    // MARK: - Weekly Skill Swipe Card (top, decoupled)

    private func weeklySkillSwipeCard(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("THIS WEEK")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.textSecondary)
                    if let first = viewModel.scheduledDays.first, let last = viewModel.scheduledDays.last {
                        Text("\(first.monthAbbrev) \(first.dayNumber) – \(last.monthAbbrev) \(last.dayNumber)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                Button {
                    focusSkillPage = min(focusSkillPage, max(focusManager.focusSkills.count - 1, 0))
                    showFocusPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add skill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            if focusManager.focusSkills.isEmpty {
                // Setup CTA
                Button { showFocusPicker = true } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "target").font(.system(size: 16)).foregroundStyle(AppColors.primary)
                        Text("Set focus skills to track your progress")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.xs)
                    .background(AppColors.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
            } else {
                // Swipeable skill pages
                TabView(selection: $focusSkillPage) {
                    ForEach(Array(focusManager.focusSkills.enumerated()), id: \.element.id) { index, skill in
                        skillChartPage(skill, index: index, viewModel: viewModel)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 190)
                .animation(.easeInOut(duration: 0.25), value: focusSkillPage)

                // Page dots
                if focusManager.focusSkills.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<focusManager.focusSkills.count, id: \.self) { i in
                            Circle()
                                .fill(i == focusSkillPage ? AppColors.primary : AppColors.separator)
                                .frame(width: i == focusSkillPage ? 8 : 6,
                                       height: i == focusSkillPage ? 8 : 6)
                                .animation(.easeInOut(duration: 0.2), value: focusSkillPage)
                        }
                    }
                    .padding(.bottom, AppSpacing.sm)
                    .padding(.top, AppSpacing.xxs)
                } else {
                    Spacer().frame(height: AppSpacing.sm)
                }
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
    }

    private func skillChartPage(_ entry: FocusSkillEntry, index: Int, viewModel: HomeViewModel) -> some View {
        VStack(spacing: AppSpacing.xs) {
            // Skill header row
            HStack(spacing: AppSpacing.xs) {
                Text(entry.icon).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Skill \(index + 1) of \(focusManager.focusSkills.count)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let rating = viewModel.skillsWithRatings.first(where: { $0.skill.id == entry.id })?.rating {
                        Text("\(rating)%")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                            .contentTransition(.numericText())
                    } else {
                        Text("—")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Text("this week")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.sm)

            // Weekly chart
            weeklySkillChart(for: entry.id, viewModel: viewModel)
                .padding(.horizontal, AppSpacing.sm)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func weeklySkillChart(for skillId: UUID, viewModel: HomeViewModel) -> some View {
        let data  = viewModel.weeklyRatings(for: skillId)
        let days  = viewModel.scheduledDays
        let minR  = max((data.map(\.rating).min() ?? 0) - 10, 0)
        let maxR  = min((data.map(\.rating).max() ?? 100) + 10, 100)
        let weekStart = days.first?.date ?? Date()
        let weekEnd   = days.last?.date  ?? Date()

        return Group {
            if data.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text("Rate this skill after a session to see your trend")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
                .frame(height: 90)
            } else {
                Chart {
                    ForEach(data, id: \.date) { point in
                        LineMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Rating", point.rating)
                        )
                        .foregroundStyle(AppColors.coral.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Day", point.date, unit: .day),
                            yStart: .value("Base", minR),
                            yEnd:   .value("Rating", point.rating)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [AppColors.coral.opacity(0.2), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Day", point.date, unit: .day),
                            y: .value("Rating", point.rating)
                        )
                        .foregroundStyle(AppColors.coral)
                        .symbolSize(data.count == 1 ? 60 : 30)
                    }
                }
                .chartXScale(domain: weekStart...weekEnd)
                .chartYScale(domain: minR...maxR)
                .chartXAxis {
                    AxisMarks(values: days.map(\.date)) { _ in
                        AxisGridLine()
                            .foregroundStyle(AppColors.separator.opacity(0.35))
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                        AxisValueLabel()
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                        AxisGridLine().foregroundStyle(AppColors.separator.opacity(0.35))
                    }
                }
                .frame(height: 90)
            }
        }
    }

    // MARK: - Weekly Schedule Card (bottom, decoupled)

    private func weeklyScheduleCard(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: 0) {
            if viewModel.scheduledDays.isEmpty {
                ProgressView().padding(AppSpacing.md)
            } else {
                ForEach(viewModel.scheduledDays) { day in
                    scheduleDayRow(day, viewModel: viewModel)
                    if day.id != viewModel.scheduledDays.last?.id {
                        Divider().padding(.leading, AppSpacing.md)
                    }
                }
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
    }

    private func scheduleDayRow(_ day: WeekScheduleDay, viewModel: HomeViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(day.dayName)
                        .font(.system(size: 14, weight: day.isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(day.isToday ? AppColors.primary : AppColors.textPrimary)
                    Text("\(day.monthAbbrev) \(day.dayNumber)")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                if day.isToday {
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }
            }
            .frame(minWidth: 80, alignment: .leading)

            Spacer()

            if day.hasLoggedSession {
                Label("Logged", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.successGreen)
                    .labelStyle(.titleAndIcon)
            } else if day.isPracticeDay {
                Button { showSessionTypeSheet = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("Log Session").font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(day.isToday ? .white : AppColors.primary)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(day.isToday ? AppColors.primary : AppColors.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .opacity(day.isFuture && !day.isToday ? 0.65 : 1)
            } else {
                Text("Rest")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 11)
        .background(day.isToday ? AppColors.primary.opacity(0.04) : Color.clear)
    }

    // MARK: - Skill Ideas Card

    private func skillIdeasCard(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SKILL IDEAS")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button {
                    newIdeaName = ""; newIdeaNotes = ""
                    showAddIdeaSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            if focusManager.skillIdeas.isEmpty {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    Text("Jot down skills you want to explore later")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
            } else {
                VStack(spacing: 0) {
                    ForEach(focusManager.skillIdeas) { idea in
                        ideaRow(idea, viewModel: viewModel)
                        if idea.id != focusManager.skillIdeas.last?.id {
                            Divider().padding(.leading, AppSpacing.sm)
                        }
                    }
                }
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .sheet(isPresented: $showAddIdeaSheet) { addIdeaSheet }
    }

    private func ideaRow(_ idea: SkillIdea, viewModel: HomeViewModel) -> some View {
        let isExpanded = expandedIdeaId == idea.id

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIdeaId = isExpanded ? nil : idea.id
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        if !idea.notes.isEmpty && !isExpanded {
                            Text(idea.notes)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    if !idea.notes.isEmpty {
                        Text(idea.notes)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            Task { await viewModel.convertIdeaToSkill(idea) }
                        } label: {
                            Label("Add to Skills", systemImage: "plus.circle")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.primary)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(AppColors.primary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            withAnimation { focusManager.deleteIdea(id: idea.id) }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }

    private var addIdeaSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Skill name")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                    TextField("e.g. ATP, Erne, Backhand roll...", text: $newIdeaName)
                        .font(.system(size: 15, design: .rounded))
                        .padding(AppSpacing.xs)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Notes (optional)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                    TextField("What do you want to remember about this skill?", text: $newIdeaNotes, axis: .vertical)
                        .font(.system(size: 15, design: .rounded))
                        .lineLimit(3...5)
                        .padding(AppSpacing.xs)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Spacer()
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .navigationTitle("Add Skill Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showAddIdeaSheet = false }
                        .foregroundStyle(AppColors.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        focusManager.addIdea(name: newIdeaName, notes: newIdeaNotes)
                        showAddIdeaSheet = false
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
                    .disabled(newIdeaName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(AppColors.cardBackground)
    }

    // MARK: - DUPR Rating Card

    @ViewBuilder
    private var duprRatingCard: some View {
        if duprService.isConnected, let profile = duprService.profile {
            Button { showDUPRStats = true } label: {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DUPR RATING")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(AppColors.textSecondary)
                            HStack(spacing: 14) {
                                duprRatingPair(label: "S", value: profile.formattedSingles, provisional: profile.singlesProvisional)
                                duprRatingPair(label: "D", value: profile.formattedDoubles, provisional: profile.doublesProvisional)
                            }
                            .padding(.top, 2)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            if let delta = duprService.singlesRatingDelta, abs(delta) > 0.001 {
                                homeDeltaBadge(delta)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(AppSpacing.sm)
                }
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
                .shadow(color: .black.opacity(0.05), radius: 14, y: 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button { showProfile = true } label: {
                HStack(spacing: AppSpacing.xs) {
                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.1))
                            .frame(width: 34, height: 34)
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.primary)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Connect DUPR")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("Sync your official pickleball rating")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.sm)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
                .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func duprRatingPair(label: String, value: String, provisional: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
            Text(value + (provisional ? " P" : ""))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primary)
                .contentTransition(.numericText())
        }
    }

    private func homeDeltaBadge(_ delta: Double) -> some View {
        let positive = delta > 0
        return HStack(spacing: 3) {
            Image(systemName: positive ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
            Text(String(format: "%.2f", abs(delta)))
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(positive ? AppColors.successGreen : AppColors.coral)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background((positive ? AppColors.successGreen : AppColors.coral).opacity(0.12))
        .clipShape(Capsule())
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
                    let progress = max(CGFloat(score) / 100.0 * 0.75, score > 0 ? 0.015 : 0)

                    // Track
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(AppColors.ringTrack,
                                style: StrokeStyle(lineWidth: 17, lineCap: .round))
                        .rotationEffect(.degrees(135))

                    // Glow — blurred copy behind the progress arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 17, lineCap: .round))
                        .rotationEffect(.degrees(135))
                        .blur(radius: 9)
                        .opacity(0.45)
                        .animation(.easeOut(duration: 1.1), value: score)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(colors: [color.opacity(0.85), color],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 17, lineCap: .round)
                        )
                        .rotationEffect(.degrees(135))
                        .animation(.easeOut(duration: 1.1), value: score)

                    // Score number
                    Text("\(score)")
                        .font(Font.custom("Sora-Bold", size: 48))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                }
                .frame(width: 160, height: 160)

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
                .padding(.bottom, AppSpacing.xxs)
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
        case 40..<55: return "Finding your rhythm. Consistency is key."
        case 55..<70: return "Solid momentum. Your effort is showing."
        case 70..<85: return "Strong and consistent. You're dialing it in."
        case 85..<95: return "Elite consistency. Top of the court."
        default:      return "All-court weapon. You're the real dill. 🥒"
        }
    }

    // MARK: - Weekly Stats Card (separate from score card)

    private func weeklyStatsCard(_ viewModel: HomeViewModel) -> some View {
        VStack(spacing: 0) {
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

        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
        .shadow(color: Color.black.opacity(0.05), radius: 14, y: 5)
    }

    // MARK: - Brine Score Inline Breakdown

    private func brineScoreBreakdown(_ viewModel: HomeViewModel) -> some View {
        let fm = FocusSkillManager.shared

        // Consistency: 40 pts
        let weeklyPts  = viewModel.weeklySessionGoal > 0
            ? Int(min(Double(viewModel.thisWeekSessionCount) / Double(viewModel.weeklySessionGoal), 1.0) * 15.0) : 0
        let streakPts  = Int(min(Double(viewModel.streakDays), 14.0) / 14.0 * 15.0)
        let habitPts   = Int(min(Double(viewModel.totalSessionsAllTime), 20.0) / 20.0 * 10.0)
        let consistencyPts = weeklyPts + streakPts + habitPts

        // Momentum: 25 pts
        let improving   = Double(viewModel.improvedSkillCount)
        let tracked     = Double(max(viewModel.totalActiveSkills, 1))
        let trendPts    = Int(min(improving / tracked, 1.0) * 15.0)
        let focusMPts   = fm.hasFocusSkills ? 5 : 0
        let ratedPts    = viewModel.weeklySkillMovers.isEmpty ? 0 : 5
        let momentumPts = trendPts + focusMPts + ratedPts

        // Engagement: 20 pts
        var engagePts = 0
        if viewModel.totalActiveSkills > 0    { engagePts += 5 }
        if viewModel.totalSessionsAllTime > 0 { engagePts += 5 }
        let drillsDone = UserDefaults.standard.integer(forKey: "pkkl_total_drills_completed")
        engagePts += Int(min(Double(drillsDone), 5.0) / 5.0 * 7.0)
        if !viewModel.completedSkills.isEmpty { engagePts += 3 }
        let engageTotal = min(engagePts, 20)

        // Focus: 15 pts
        var focusPts = 0
        if fm.hasFocusSkills                  { focusPts += 5 }
        if DUPRService.shared.isConnected      { focusPts += 4 }
        if PlayerProfile.current().isComplete  { focusPts += 3 }
        if !fm.skillIdeas.isEmpty              { focusPts += 3 }
        let focusTotal = min(focusPts, 15)

        return VStack(spacing: 0) {
            Divider()

            VStack(spacing: 0) {
                scoreRow(icon: "flame.fill",      color: AppColors.warningOrange,
                         title: "Consistency",    subtitle: "Weekly goal, streak & session history",
                         pts: consistencyPts,      maxPts: 40)
                Divider().padding(.leading, 52)
                scoreRow(icon: "arrow.up.right",  color: AppColors.highlight,
                         title: "Momentum",       subtitle: "Skills improving & rated this week",
                         pts: momentumPts,         maxPts: 25)
                Divider().padding(.leading, 52)
                scoreRow(icon: "sparkles",        color: AppColors.trophyGold,
                         title: "Engagement",     subtitle: "Active skills, drills & completions",
                         pts: engageTotal,         maxPts: 20)
                Divider().padding(.leading, 52)
                scoreRow(icon: "target",          color: AppColors.primary,
                         title: "Focus",          subtitle: "Focus skills, DUPR & profile",
                         pts: focusTotal,          maxPts: 15)
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
