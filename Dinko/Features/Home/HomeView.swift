import SwiftUI

struct HomeView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @Binding var selectedTab: Int
    var refreshID: UUID = UUID()
    @State private var viewModel: HomeViewModel?
    @State private var contentReady = false
    @State private var expandedSkillId: UUID?
    @State private var sliderValue: Double = 0
    @State private var isSavingRating = false
    @State private var showAddSkill = false
    @State private var showProfile = false
    @State private var showNameDropdown = false
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
                greetingHeader(viewModel)
                    .staggeredAppearance(index: 0)

                if !hasSeenProfilePrompt && !PlayerProfile.current().isComplete {
                    completeProfileBanner
                        .staggeredAppearance(index: 1)
                }

                overallSkillCard(viewModel)
                    .staggeredAppearance(index: 1)
                sessionsCard(viewModel)
                    .staggeredAppearance(index: 2)
                if !viewModel.weeklySkillMovers.isEmpty {
                    skillMoversCard(viewModel)
                        .staggeredAppearance(index: 3)
                }
                skillsSection(viewModel)
                    .staggeredAppearance(index: 4)
                todaysFocusSection(viewModel)
                    .staggeredAppearance(index: 5)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xxs)
            .padding(.bottom, AppSpacing.xl + 60)
            .contentLoadTransition(isLoaded: contentReady)
        }
        .background(AppColors.backgroundGradient)
        .onTapGesture {
            if showNameDropdown {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showNameDropdown = false
                }
            }
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    // MARK: - Name Header

    private func greetingHeader(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showNameDropdown.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(viewModel.playerName)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .rotationEffect(.degrees(showNameDropdown ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
            .accessibilityHint("Opens profile menu")

            if showNameDropdown {
                nameDropdownMenu
                    .transition(
                        .asymmetric(
                            insertion: .opacity
                                .combined(with: .scale(scale: 0.95, anchor: .topLeading))
                                .combined(with: .offset(y: -4)),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.98, anchor: .topLeading))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, AppSpacing.xs)
    }

    private var nameDropdownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            dropdownRow(icon: "person.fill", label: "Profile") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showNameDropdown = false
                }
                showProfile = true
            }

            Divider()
                .padding(.leading, 36)

            dropdownRow(icon: "gearshape", label: "Settings") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showNameDropdown = false
                }
                showProfile = true
            }
        }
        .padding(.vertical, 4)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.top, AppSpacing.xxs)
    }

    private func dropdownRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    // MARK: - Overall Skill Card (Hero)

    private func overallSkillCard(_ viewModel: HomeViewModel) -> some View {
        let tier = SkillTier(rating: viewModel.averageRating)

        return VStack(spacing: 0) {
            // Centered progress ring
            ZStack {
                Circle()
                    .stroke(AppColors.primary.opacity(0.1), lineWidth: 10)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(viewModel.averageRating) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.primary.opacity(0.6), AppColors.primary],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: -2) {
                    Text("\(viewModel.averageRating)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("%")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)

            // Tier line
            HStack(spacing: 4) {
                Image(systemName: tier.sfSymbol)
                    .font(.system(size: 12))
                Text(tier.displayName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                if let next = tier.nextTier {
                    let pointsToNext = SkillTier.pointsToNext(for: viewModel.averageRating)
                    Text("\u{00B7}")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(pointsToNext) pts to \(next.displayName)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(tier.color)
            .padding(.bottom, AppSpacing.sm)

            // Divider
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
                .padding(.horizontal, AppSpacing.sm)

            // Stats row
            HStack(spacing: 0) {
                if viewModel.streakDays > 0 {
                    statItem(text: "\u{1F525} \(viewModel.streakDays)-day streak")
                }

                if viewModel.completedSkills.count > 0 {
                    statItem(text: "\u{2705} \(viewModel.completedSkills.count) mastered")
                }

                if let improved = viewModel.mostImprovedSkillName, viewModel.mostImprovedDelta > 0 {
                    statItem(text: "\u{1F4C8} \(improved) +\(viewModel.mostImprovedDelta)%")
                }
            }
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.sm)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppSpacing.heroCornerRadius)
                .stroke(AppColors.heroCardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func statItem(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Sessions This Week Card

    private func sessionsCard(_ viewModel: HomeViewModel) -> some View {
        let count = viewModel.thisWeekSessionCount
        let goal = viewModel.weeklySessionGoal
        let remaining = max(0, goal - count)
        let progress = goal > 0 ? Double(count) / Double(goal) : 0

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Sessions")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("/ \(goal)")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if count >= goal {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                        Text("Goal reached!")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppColors.successGreen)
                } else {
                    Text("\(remaining) left")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            ProgressBar(progress: min(progress, 1.0))
                .padding(.top, 2)
        }
        .infoCard()
    }

    // MARK: - Skill Movers This Week

    private func skillMoversCard(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("This Week's Movers")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.weeklySkillMovers.enumerated()), id: \.element.skill.id) { index, item in
                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(SkillTier(rating: item.currentRating).color)
                            .frame(width: 10, height: 10)

                        Text(item.skill.name)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(item.delta > 0 ? "+\(item.delta)%" : "\(item.delta)%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(item.delta > 0 ? AppColors.successGreen : AppColors.coral)
                    }
                    .padding(.vertical, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.xxs)

                    if index < viewModel.weeklySkillMovers.count - 1 {
                        Divider()
                            .padding(.leading, AppSpacing.lg)
                    }
                }
            }
            .infoCard()
        }
    }

    // MARK: - Skills Section

    private func skillsSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Section header — outside the card
            HStack(alignment: .firstTextBaseline) {
                Text("My Skills")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    showAddSkill = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .frame(width: 28, height: 28)
                        .background(AppColors.primary.opacity(0.12))
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
                            .background(AppColors.primary)
                            .clipShape(Capsule())
                    }
                    .padding(.top, AppSpacing.xxs)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .infoCard()
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
                .infoCard()
            }
        }
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
                        .tint(AppColors.primary)

                    Text("\(Int(sliderValue))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
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
                                .background(AppColors.primary)
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

    // MARK: - Today's Focus

    private func todaysFocusSection(_ viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionHeaderView(title: "Today's Focus", actionTitle: "See All") {
                selectedTab = 3
            }

            if let drill = viewModel.topDrill {
                NavigationLink {
                    DrillDetailView(drill: drill) {
                        await viewModel.markDrillDone(drill.id)
                    }
                } label: {
                    todaysFocusCard(drill)
                }
                .buttonStyle(.pressable)
            } else {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(AppColors.textSecondary.opacity(0.5))

                    Text("No drills yet \u{2014} Log a session with the Coach to get personalized drills.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func todaysFocusCard(_ drill: HomeRecommendedDrill) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Row 1: type pill + duration
            HStack {
                drillTypePill(for: drill)
                Spacer()
                Text("\(drill.durationMinutes) min")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Drill name
            Text(drill.drillName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            // Target skill
            Text("Targets: \(drill.skillName)")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            // Reason (why it was recommended)
            if !drill.reason.isEmpty {
                Text(drill.reason)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .italic()
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .coachCard()
    }

    private func drillTypePill(for drill: HomeRecommendedDrill) -> some View {
        let info = drillTypeInfo(for: drill)
        return Text("\(info.icon) \(info.label)")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(info.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(info.color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func drillTypeInfo(for drill: HomeRecommendedDrill) -> (icon: String, label: String, color: Color) {
        let lower = drill.drillName.lowercased()
        if lower.contains("reflex") || lower.contains("reaction") {
            return ("\u{26A1}", "Reflex", AppColors.drillOrange)
        }
        if lower.contains("placement") || lower.contains("target") || lower.contains("accuracy") {
            return ("\u{1F3AF}", "Placement", AppColors.primary)
        }
        if lower.contains("power") || lower.contains("smash") || lower.contains("speed") {
            return ("\u{1F525}", "Power", AppColors.coral)
        }
        if lower.contains("dink") || lower.contains("drop") || lower.contains("touch") || lower.contains("soft") {
            return ("\u{1F3AF}", "Touch", AppColors.successGreen)
        }
        if lower.contains("strategy") || lower.contains("position") || lower.contains("transition") {
            return ("\u{1F9E0}", "Strategy", AppColors.drillPurple)
        }
        if lower.contains("serve") || lower.contains("return") {
            return ("\u{1F3AF}", "Serve", AppColors.primary)
        }
        if lower.contains("drive") || lower.contains("attack") {
            return ("\u{1F525}", "Attack", AppColors.coral)
        }
        if lower.contains("counter") {
            return ("\u{26A1}", "Counter", AppColors.drillOrange)
        }
        return ("\u{1F3F8}", "Drill", AppColors.primary)
    }
}

#Preview {
    NavigationStack {
        HomeView(selectedTab: .constant(0), refreshID: UUID())
    }
}
