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
    @State private var ringProgress: CGFloat = 0
    @State private var showAllAchievements = false
    @State private var celebratingAchievement: Achievement?
    @AppStorage("pkkl_has_seen_profile_prompt") private var hasSeenProfilePrompt = false

    var body: some View {
        Group {
            if let viewModel {
                homeContent(viewModel)
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
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Deleting account...")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.lg)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func homeContent(_ viewModel: HomeViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                heroSection(viewModel)
                    .staggeredAppearance(index: 0)

                if !hasSeenProfilePrompt && !PlayerProfile.current().isComplete {
                    completeProfileBanner
                        .staggeredAppearance(index: 1)
                }

                coachRecommendationSection(viewModel)
                    .staggeredAppearance(index: 2)

                weeklyMomentumSection(viewModel)
                    .staggeredAppearance(index: 3)

                skillsSpotlightSection(viewModel)
                    .staggeredAppearance(index: 4)

                achievementsSection(viewModel)
                    .staggeredAppearance(index: 5)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xl + 60)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .background(AppColors.backgroundGradient)
        .refreshable {
            await viewModel.loadDashboard()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showAddSkill) {
            AddEditSkillView()
                .presentationDetents([.medium])
                .onDisappear {
                    Task { await viewModel.loadDashboard() }
                }
        }
    }

    // MARK: - Hero Section

    private func heroSection(_ viewModel: HomeViewModel) -> some View {
        let count = viewModel.thisWeekSessionCount
        let goal = viewModel.weeklySessionGoal
        let goalMet = count >= goal
        let targetProgress = goal > 0
            ? min(CGFloat(count) / CGFloat(goal), 1.0)
            : 0

        return VStack(spacing: AppSpacing.sm) {
            // Top bar: greeting + profile avatar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.greetingText),")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Text(viewModel.playerName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                Button {
                    showProfile = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.primary.opacity(0.7))
                }
            }

            // Large circular progress ring — weekly session goal (Bevel-style)
            let ringSize: CGFloat = 160
            let strokeWidth: CGFloat = 18

            ZStack {
                // Track (subtle light gray, no glow)
                Circle()
                    .stroke(AppColors.separator.opacity(0.25), lineWidth: strokeWidth)

                // Progress arc — gradient spans full 360°, trim reveals proportionally
                if ringProgress > 0 {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "C6E84B"),  // light yellow-green
                                    AppColors.primaryLight,
                                    AppColors.primary,
                                    AppColors.primaryDark,  // deep green
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 10, x: 0, y: 0)
                }

                // White inner disc for depth
                Circle()
                    .fill(.white)
                    .frame(width: ringSize - strokeWidth * 2 - 8, height: ringSize - strokeWidth * 2 - 8)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                // Inner content
                VStack(spacing: 2) {
                    if goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(AppColors.successGreen)

                        Text("Goal reached!")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.successGreen)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 1) {
                            Text("\(count)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                                .contentTransition(.numericText())
                            Text("/\(goal)")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        Text("sessions this week")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: ringSize - strokeWidth * 2 - 20)
            }
            .frame(width: ringSize, height: ringSize)
            .padding(.vertical, AppSpacing.sm)
            .onChange(of: viewModel.isLoaded) {
                animateRing(to: targetProgress)
            }
            .onAppear {
                if viewModel.isLoaded {
                    animateRing(to: targetProgress)
                }
            }

            // Motivational text
            Text(heroMessage(viewModel))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            // Streak badge
            if viewModel.streakDays > 0 {
                Label("\(viewModel.streakDays)-day streak", systemImage: "flame.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.warningOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(AppColors.warningOrange.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Action buttons
            HStack(spacing: AppSpacing.xs) {
                Button {
                    showSessionTypeSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                        Text("Log Session")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.pressable)

                Button {
                    selectedTab = 1
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                        Text("Coach")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    private func animateRing(to target: CGFloat) {
        ringProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 1.2)) {
                ringProgress = target
            }
        }
    }

    private func heroMessage(_ viewModel: HomeViewModel) -> String {
        let count = viewModel.thisWeekSessionCount
        let goal = viewModel.weeklySessionGoal
        if count >= goal {
            return "You hit your weekly goal!"
        }
        let remaining = goal - count
        if remaining == 1 {
            return "Just 1 more session to hit your goal!"
        }
        if count == 0 {
            return "Start your week strong \u{2014} log your first session!"
        }
        return "\(remaining) more sessions to hit your goal!"
    }

    // MARK: - Coach Recommendation

    private func coachRecommendationSection(_ viewModel: HomeViewModel) -> some View {
        Group {
            if viewModel.totalActiveSkills > 0 {
                HStack(spacing: AppSpacing.xs) {
                    CoachMascot(state: viewModel.mascotState, size: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.coachingMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            selectedTab = 2
                        } label: {
                            Text(viewModel.coachingActionLabel)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.primary)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .coachCard()
            }
        }
    }

    // MARK: - Weekly Momentum

    private func weeklyMomentumSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("This Week")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.xs) {
                momentumTile(
                    value: "\(viewModel.thisWeekSessionCount)",
                    label: "Sessions",
                    icon: "figure.pickleball",
                    color: AppColors.primary
                )

                momentumTile(
                    value: "\(viewModel.streakDays)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: AppColors.warningOrange
                )

                momentumTile(
                    value: "\(viewModel.improvedSkillCount)",
                    label: "Improved",
                    icon: "arrow.up.right",
                    color: AppColors.successGreen
                )
            }
        }
    }

    private func momentumTile(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .floatingCard()
    }

    // MARK: - Skills Spotlight

    private func skillsSpotlightSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeaderView(title: "Skills Snapshot", actionTitle: "See All") {
                selectedTab = 2
            }

            if viewModel.skillsWithRatings.isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "target")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("Add your first skill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Track your pickleball skills and rate your progress.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showAddSkill = true
                    } label: {
                        Text("Add Skill")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .infoCard()
            } else {
                // Curated spotlight cards
                let cards = buildSpotlightCards(viewModel)
                VStack(spacing: AppSpacing.xs) {
                    ForEach(cards, id: \.skill.id) { card in
                        spotlightCard(
                            skill: card.skill,
                            rating: card.rating,
                            label: card.label,
                            labelColor: card.labelColor
                        )
                    }
                }
            }
        }
    }

    private struct SpotlightItem {
        let skill: Skill
        let rating: Int
        let label: String
        let labelColor: Color
    }

    private func buildSpotlightCards(_ viewModel: HomeViewModel) -> [SpotlightItem] {
        var cards: [SpotlightItem] = []
        var usedIds: Set<UUID> = []

        // 1. Weakest skill
        if let weak = viewModel.weakestSkill {
            cards.append(SpotlightItem(
                skill: weak.skill,
                rating: weak.rating,
                label: "Needs Work",
                labelColor: AppColors.coral
            ))
            usedIds.insert(weak.skill.id)
        }

        // 2. Focus skill (declining or weakest — dedupe)
        if let focus = viewModel.focusSkill, !usedIds.contains(focus.skill.id) {
            cards.append(SpotlightItem(
                skill: focus.skill,
                rating: focus.rating,
                label: "Focus",
                labelColor: AppColors.warningOrange
            ))
            usedIds.insert(focus.skill.id)
        }

        // 3. Strongest skill (dedupe)
        if let strong = viewModel.strongestSkill, !usedIds.contains(strong.skill.id) {
            cards.append(SpotlightItem(
                skill: strong.skill,
                rating: strong.rating,
                label: "Strongest",
                labelColor: AppColors.successGreen
            ))
            usedIds.insert(strong.skill.id)
        }

        // Fill remaining slots from skillsWithRatings if we have fewer than 3
        if cards.count < 3 {
            for item in viewModel.skillsWithRatings where !usedIds.contains(item.skill.id) {
                cards.append(SpotlightItem(
                    skill: item.skill,
                    rating: item.rating,
                    label: "",
                    labelColor: .clear
                ))
                usedIds.insert(item.skill.id)
                if cards.count >= 3 { break }
            }
        }

        return Array(cards.prefix(3))
    }

    private func spotlightCard(skill: Skill, rating: Int, label: String, labelColor: Color) -> some View {
        let tier = SkillTier(rating: rating)

        return HStack(spacing: AppSpacing.xs) {
            // Icon
            Circle()
                .fill(tier.color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(skill.iconName)
                        .font(.system(size: 16))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(skill.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    if !label.isEmpty {
                        Text(label)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(labelColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(labelColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                ProgressBar(progress: Double(rating) / 100.0, tint: tier.color)
            }

            Text("\(rating)%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .frame(width: 44, alignment: .trailing)
        }
        .infoCard()
    }

    // MARK: - Achievements

    private func achievementsSection(_ viewModel: HomeViewModel) -> some View {
        let unlocked = viewModel.achievements.filter(\.isUnlocked)
        let locked = viewModel.achievements.filter { !$0.isUnlocked }

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            SectionHeaderView(title: "Badges", actionTitle: "See All") {
                showAllAchievements = true
            }

            // Unlocked count
            Text("\(unlocked.count) of \(viewModel.achievements.count) earned")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            // Recent unlocked + next locked badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // Show unlocked first (most recent = last earned, so reverse)
                    ForEach(unlocked.reversed(), id: \.achievement.id) { item in
                        AchievementBadge(
                            name: item.achievement.name,
                            iconName: item.achievement.iconName,
                            isUnlocked: true,
                            badgeColor: item.achievement.color
                        )
                    }

                    // Then show next few locked badges
                    ForEach(locked.prefix(4), id: \.achievement.id) { item in
                        AchievementBadge(
                            name: item.achievement.name,
                            iconName: item.achievement.iconName,
                            isUnlocked: false,
                            badgeColor: item.achievement.color
                        )
                    }
                }
                .padding(.vertical, AppSpacing.xxs)
            }

            // Newly unlocked celebration
            if let newest = viewModel.newlyUnlockedAchievements.first, celebratingAchievement == nil {
                Color.clear
                    .onAppear {
                        celebratingAchievement = newest
                    }
            }
        }
        .sheet(isPresented: $showAllAchievements) {
            allAchievementsSheet(viewModel)
        }
        .overlay {
            if let achievement = celebratingAchievement {
                achievementCelebration(achievement)
            }
        }
    }

    private func achievementCelebration(_ achievement: Achievement) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(AppAnimations.springSmooth) {
                        celebratingAchievement = nil
                    }
                }

            VStack(spacing: AppSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppSpacing.xs)
                        .fill(achievement.color)
                        .frame(width: 80, height: 80)

                    Image(systemName: achievement.iconName)
                        .font(.system(size: 36))
                        .foregroundStyle(AppColors.textPrimary)
                }

                Text("Badge Earned!")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text(achievement.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(achievement.color)

                Text(achievement.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation(AppAnimations.springSmooth) {
                        celebratingAchievement = nil
                    }
                } label: {
                    Text("Nice!")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, AppSpacing.xxs)
            }
            .padding(AppSpacing.lg)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, AppSpacing.xl)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
        .animation(AppAnimations.springBouncy, value: celebratingAchievement?.id)
    }

    private func allAchievementsSheet(_ viewModel: HomeViewModel) -> some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80), spacing: AppSpacing.sm)
                ], spacing: AppSpacing.md) {
                    ForEach(viewModel.achievements, id: \.achievement.id) { item in
                        VStack(spacing: AppSpacing.xxs) {
                            AchievementBadge(
                                name: item.achievement.name,
                                iconName: item.achievement.iconName,
                                isUnlocked: item.isUnlocked,
                                badgeColor: item.achievement.color
                            )

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

    // MARK: - Complete Profile Banner

    private var completeProfileBanner: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Complete your profile")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Get personalized coaching tips")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Button {
                showProfile = true
            } label: {
                Text("Set up")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }

            Button {
                withAnimation { hasSeenProfilePrompt = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .infoCard()
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0), showSessionTypeSheet: .constant(false), refreshID: UUID())
    }
}
