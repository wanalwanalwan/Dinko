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
                completedSkillsSummary(viewModel)
                    .staggeredAppearance(index: 2)
                skillsSection(viewModel)
                    .staggeredAppearance(index: 3)
                recommendedDrillsSection(viewModel)
                    .staggeredAppearance(index: 4)
                streakBanner(viewModel)
                    .staggeredAppearance(index: 5)
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
                let currentTier = SkillTier(rating: Int(sliderValue))

                VStack(spacing: AppSpacing.xs) {
                    // Tier label + large value
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xxs) {
                        Text("\(Int(sliderValue))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(currentTier.color)
                            .contentTransition(.numericText())

                        Text("%")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(currentTier.color.opacity(0.6))

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: currentTier.sfSymbol)
                                .font(.system(size: 11))
                            Text(currentTier.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(currentTier.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(currentTier.color.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    // Slider
                    Slider(value: $sliderValue, in: 0...100, step: 1)
                        .tint(currentTier.color)

                    // Save / Cancel row
                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            withAnimation(AppAnimations.springSmooth) {
                                expandedSkillId = nil
                            }
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppColors.background)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

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
                            Text(Int(sliderValue) != rating ? "Save" : "Done")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Int(sliderValue) != rating ? AppColors.teal : AppColors.textSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(isSavingRating)
                    }
                }
                .padding(AppSpacing.xs)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        let overallTier = SkillTier(rating: viewModel.averageRating)

        return VStack(spacing: AppSpacing.sm) {
            // Top row: label + tier badge
            HStack {
                Text("OVERALL LEVEL")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(0.3)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: overallTier.sfSymbol)
                        .font(.system(size: 10))
                    Text(overallTier.displayName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(overallTier.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(overallTier.color.opacity(0.1))
                .clipShape(Capsule())
            }

            // Center: large percentage + ring
            HStack(spacing: AppSpacing.md) {
                // Circular progress ring
                ZStack {
                    Circle()
                        .stroke(AppColors.separator, lineWidth: 6)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.averageRating) / 100.0)
                        .stroke(overallTier.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))

                    Text("\(viewModel.averageRating)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }

                // Stats column
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.teal)
                        Text("\(viewModel.totalActiveSkills) skills tracked")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.coral)
                        Text("\(viewModel.streakDays)-day streak")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }

                    if let improved = viewModel.mostImprovedSkillName, viewModel.mostImprovedDelta > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.successGreen)
                            Text("\(improved) +\(viewModel.mostImprovedDelta)%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.successGreen)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Completed Skills Summary

    private func completedSkillsSummary(_ viewModel: HomeViewModel) -> some View {
        let completed = viewModel.completedSkills.count
        let total = viewModel.totalSkillsIncludingCompleted
        let progress: CGFloat = total > 0 ? CGFloat(completed) / CGFloat(total) : 0

        return VStack(spacing: AppSpacing.sm) {
            HStack {
                Text("COMPLETED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(0.3)

                Spacer()

                Text("\(completed)/\(total)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.teal)
            }

            HStack(spacing: AppSpacing.sm) {
                // Mini ring
                ZStack {
                    Circle()
                        .stroke(AppColors.separator, lineWidth: 4)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppColors.successGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.successGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(completed) skill\(completed == 1 ? "" : "s") mastered")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    if total > completed {
                        Text("\(total - completed) more to go")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    } else if total > 0 {
                        Text("All skills mastered!")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.successGreen)
                    }
                }

                Spacer()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.separator)
                        .frame(height: 6)

                    Capsule()
                        .fill(AppColors.successGreen)
                        .frame(width: geo.size.width * progress, height: 6)
                }
            }
            .frame(height: 6)
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
