import SwiftUI

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @Binding var selectedTab: Int
    @State private var viewModel: HomeViewModel?
    @State private var contentReady = false
    @State private var ratingSkill: Skill?
    @State private var ratingSkillCurrentRating: Int = 0
    @State private var showAddSkill = false

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
                    sessionRepository: dependencies.sessionRepository
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
                greetingHeader(viewModel)
                    .staggeredAppearance(index: 0)
                skillsSection(viewModel)
                    .staggeredAppearance(index: 1)
                recommendedDrillsSection(viewModel)
                    .staggeredAppearance(index: 2)
                completedSkillsSection(viewModel)
                    .staggeredAppearance(index: 3)
                streakBanner(viewModel)
                    .staggeredAppearance(index: 4)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.lg)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Greeting Header

    private func greetingHeader(_ viewModel: HomeViewModel) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(viewModel.todayDateText.uppercased())
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                VStack(alignment: .leading, spacing: 0) {
                    Text("\(viewModel.greetingText),")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(viewModel.playerName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                }
            }

            Spacer()

            Menu {
                Link(destination: AppURLs.privacyPolicy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }

                Link(destination: AppURLs.termsOfService) {
                    Label("Terms of Service", systemImage: "doc.text")
                }

                Divider()

                Button(role: .destructive) {
                    Task { await authViewModel?.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    authViewModel?.showDeleteConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.cardBackground)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Account Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Skills Section

    private func skillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("MY SKILLS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Button {
                    showAddSkill = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.teal)
                        .frame(width: 28, height: 28)
                        .background(AppColors.teal.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            if viewModel.skillsWithRatings.isEmpty {
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
                            .background(AppColors.teal)
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            } else {
                ScrollView {
                    VStack(spacing: AppSpacing.xxs) {
                        ForEach(viewModel.skillsWithRatings, id: \.skill.id) { item in
                            skillRow(skill: item.skill, rating: item.rating)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .sheet(item: $ratingSkill) { skill in
            RateSkillView(
                skillName: skill.name,
                currentRating: ratingSkillCurrentRating
            ) { newRating, notes in
                await viewModel.saveRating(for: skill.id, rating: newRating, notes: notes)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAddSkill) {
            AddEditSkillView()
                .presentationDetents([.medium])
                .onDisappear {
                    Task { await viewModel.loadDashboard() }
                }
        }
    }

    private func skillRow(skill: Skill, rating: Int) -> some View {
        let tier = SkillTier(rating: rating)

        return Button {
            ratingSkillCurrentRating = rating
            ratingSkill = skill
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(tier.color)
                    .frame(width: 10, height: 10)

                Text(skill.name)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.background)
                            .frame(height: 6)

                        Capsule()
                            .fill(tier.color)
                            .frame(width: geo.size.width * CGFloat(rating) / 100.0, height: 6)
                    }
                }
                .frame(width: 80, height: 6)

                Text("\(rating)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Drills

    private func recommendedDrillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "Recommended Drills", actionTitle: "See All") {
                selectedTab = 3
            }

            if viewModel.recommendedDrills.isEmpty {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("No drills yet \u{2014} Log a session with the Coach to get personalized drills.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            } else {
                ForEach(viewModel.recommendedDrills) { drill in
                    NavigationLink {
                        DrillDetailView(drill: drill) {
                            await viewModel.markDrillDone(drill.id)
                        }
                    } label: {
                        DrillCardView(drill: drill)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    // MARK: - Completed Skills

    private func completedSkillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "Completed Skills")

            if viewModel.completedSkills.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundStyle(AppColors.successGreen.opacity(0.4))

                    Text("Your Journey Starts Here")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Rate a skill to 100% to see it here.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Button {
                        selectedTab = 2
                    } label: {
                        Text("View all skills")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.completedSkills) { item in
                            CompletedSkillCardView(skill: item)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteCompletedSkill(item.id) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Streak Banner

    private func streakBanner(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Keep the streak alive!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            (Text("You\u{2019}ve practiced for ")
                .foregroundColor(.white.opacity(0.85))
            + Text("\(viewModel.streakDays) days")
                .foregroundColor(.white)
                .bold()
            + Text(" in a row. \(viewModel.daysToWeeklyGoal) more to hit your weekly goal.")
                .foregroundColor(.white.opacity(0.85)))
                .font(.system(size: 14, design: .rounded))
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                .fill(AppColors.surfaceDark)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Streak: \(viewModel.streakDays) days in a row. \(viewModel.daysToWeeklyGoal) more to hit your weekly goal.")
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0))
    }
}
