import SwiftUI

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @Binding var selectedTab: Int
    @State private var viewModel: HomeViewModel?
    @State private var contentReady = false
    @State private var expandedSkillId: UUID?
    @State private var sliderValue: Double = 0
    @State private var isSavingRating = false
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
                overallSkillLevelSection(viewModel)
                    .staggeredAppearance(index: 1)
                skillsSection(viewModel)
                    .staggeredAppearance(index: 2)
                recommendedDrillsSection(viewModel)
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
                VStack(spacing: 0) {
                    ForEach(viewModel.skillsWithRatings, id: \.skill.id) { item in
                        skillRow(skill: item.skill, rating: item.rating, viewModel: viewModel)

                        if item.skill.id != viewModel.skillsWithRatings.last?.skill.id {
                            Divider()
                                .padding(.leading, AppSpacing.lg)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .sheet(isPresented: $showAddSkill) {
            AddEditSkillView()
                .presentationDetents([.medium])
                .onDisappear {
                    Task { await viewModel.loadDashboard() }
                }
        }
    }

    private func skillRow(skill: Skill, rating: Int, viewModel: HomeViewModel) -> some View {
        let tier = SkillTier(rating: rating)
        let isOpen = expandedSkillId == skill.id

        return VStack(spacing: 0) {
            // Collapsed row — tap to expand/collapse
            Button {
                withAnimation(AppAnimations.springSmooth) {
                    if isOpen {
                        expandedSkillId = nil
                    } else {
                        sliderValue = Double(rating)
                        expandedSkillId = skill.id
                    }
                }
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

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xxs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Inline rating slider
            if isOpen {
                HStack(spacing: AppSpacing.xs) {
                    Slider(value: $sliderValue, in: 0...100, step: 1)
                        .tint(AppColors.teal)

                    Text("\(Int(sliderValue))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                        .frame(width: 38, alignment: .trailing)
                        .contentTransition(.numericText())

                    if Int(sliderValue) != rating {
                        Button {
                            isSavingRating = true
                            Task {
                                let _ = await viewModel.saveRating(for: skill.id, rating: Int(sliderValue), notes: nil)
                                isSavingRating = false
                                withAnimation(AppAnimations.springSmooth) {
                                    expandedSkillId = nil
                                }
                            }
                        } label: {
                            Text("Save")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppColors.teal)
                                .clipShape(Capsule())
                        }
                        .disabled(isSavingRating)
                    } else {
                        Button {
                            withAnimation(AppAnimations.springSmooth) {
                                expandedSkillId = nil
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(AppColors.background)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xs)
                .transition(.scale(scale: 0.95, anchor: .top).combined(with: .opacity))
            }
        }
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

    // MARK: - Overall Skill Level

    private func overallSkillLevelSection(_ viewModel: HomeViewModel) -> some View {
        let tier = SkillTier(rating: viewModel.averageRating)
        let strongest = viewModel.skillsWithRatings.max(by: { $0.rating < $1.rating })

        return VStack(spacing: 0) {
            // Heading
            Text("OVERALL SKILL LEVEL")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xxxs)

            // Top section: ring + stats
            HStack(spacing: AppSpacing.md) {
                // Circular progress ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(AppColors.teal.opacity(0.1), lineWidth: 8)
                        .frame(width: 88, height: 88)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.averageRating) / 100.0)
                        .stroke(
                            AngularGradient(
                                colors: [AppColors.teal.opacity(0.6), AppColors.teal],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(-90))

                    // Center value
                    VStack(spacing: -2) {
                        Text("\(viewModel.averageRating)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                // Right: tier + context stats
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    // Tier badge
                    HStack(spacing: 4) {
                        Image(systemName: tier.sfSymbol)
                            .font(.system(size: 10))
                        Text(tier.displayName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(tier.color)

                    // Tier progress to next
                    if let next = tier.nextTier {
                        let pointsToNext = SkillTier.pointsToNext(for: viewModel.averageRating)
                        Text("\(pointsToNext) pts to \(next.displayName)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Streak
                    if viewModel.streakDays > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.coral)
                            Text("\(viewModel.streakDays)-day streak")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    // Most improved
                    if let improved = viewModel.mostImprovedSkillName, viewModel.mostImprovedDelta > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColors.successGreen)
                            Text("\(improved) +\(viewModel.mostImprovedDelta)%")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.successGreen)
                        }
                    }
                }

                Spacer()
            }
            .padding(AppSpacing.sm)

            // Bottom divider bar with meta stats
            HStack {
                Text("\(viewModel.totalActiveSkills) active")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                if viewModel.completedSkills.count > 0 {
                    Text("\u{00B7}")
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(viewModel.completedSkills.count) completed")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.successGreen)
                }

                if let best = strongest, best.rating > 0 {
                    Text("\u{00B7}")
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(best.skill.name) \(best.rating)%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.background)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
    }

    // MARK: - Completed Skills Summary

    private func completedSkillsSummary(_ viewModel: HomeViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(AppColors.teal)

            VStack(alignment: .leading, spacing: 2) {
                Text("Completed Skills")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                HStack(spacing: 4) {
                    Text("\(viewModel.completedSkills.count)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                    Text("of \(viewModel.totalSkillsIncludingCompleted) mastered")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
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
