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
        let tier = SkillTier(rating: viewModel.averageRating)

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

            // Mascot + motivational message
            VStack(spacing: AppSpacing.xs) {
                CoachMascot(state: viewModel.mascotState, size: 80)

                if viewModel.totalActiveSkills > 0 {
                    Text(heroMessage(viewModel))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Ready to start tracking your game?")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Tier progress bar
            if viewModel.totalActiveSkills > 0 {
                VStack(spacing: AppSpacing.xxs) {
                    HStack(spacing: 4) {
                        Image(systemName: tier.sfSymbol)
                            .font(.system(size: 12))
                        Text(tier.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))

                        Spacer()

                        if let next = tier.nextTier {
                            let pointsToNext = SkillTier.pointsToNext(for: viewModel.averageRating)
                            Text("\(pointsToNext) pts to \(next.displayName)")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .foregroundStyle(tier.color)

                    ProgressBar(
                        progress: SkillTier.tierProgress(for: viewModel.averageRating),
                        tint: tier.color
                    )
                }
            }

            // Start Training CTA
            Button {
                showSessionTypeSheet = true
            } label: {
                Text("Start Training")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.pressable)

            // Streak + sessions inline stats
            if viewModel.streakDays > 0 || viewModel.thisWeekSessionCount > 0 {
                HStack(spacing: AppSpacing.md) {
                    if viewModel.streakDays > 0 {
                        Label("\(viewModel.streakDays)-day streak", systemImage: "flame.fill")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.warningOrange)
                    }

                    if viewModel.thisWeekSessionCount > 0 {
                        Label(
                            "\(viewModel.thisWeekSessionCount) session\(viewModel.thisWeekSessionCount == 1 ? "" : "s") this week",
                            systemImage: "calendar"
                        )
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    private func heroMessage(_ viewModel: HomeViewModel) -> String {
        if viewModel.averageRating >= 80 {
            return "You're playing at an elite level!"
        }
        if viewModel.streakDays >= 7 {
            return "Incredible streak! Keep it going!"
        }
        if viewModel.improvedSkillCount > 0 {
            return "\(viewModel.improvedSkillCount) skill\(viewModel.improvedSkillCount == 1 ? "" : "s") improved this week!"
        }
        return "Your overall rating: \(viewModel.averageRating)%"
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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall)
                .stroke(AppColors.cardBorder, lineWidth: 0.5)
        )
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
