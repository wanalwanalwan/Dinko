import SwiftUI

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingRateSkill = false
    @State private var showingAddSubskill = false
    @State private var showingDeleteConfirm = false
    @State private var showingCoaching = false
    @State private var showingProgressCheckers = false
    @State private var ratingNotesExpanded = false
    @State private var contentReady = false
    @State private var celebrationVisible = false
    let skill: Skill

    var body: some View {
        Group {
            if let viewModel {
                detailContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = SkillDetailViewModel(
                    skill: skill,
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository,
                    progressCheckerRepository: dependencies.progressCheckerRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadDetail()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadDetail() }
            }
        }
    }

    private func detailContent(_ viewModel: SkillDetailViewModel) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    ratingHero(viewModel)

                    if viewModel.isParentSkill {
                        subskillsSection(viewModel)
                    }

                    if !viewModel.progressCheckers.isEmpty {
                        progressCheckersCard(viewModel)
                    }

                    notesSection(viewModel)
                    coachingButton(viewModel)
                    drillsSection(viewModel)
                    ratingNotesSection(viewModel)

                    Spacer(minLength: 0)

                    actionButtons(viewModel)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.lg)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .frame(minHeight: geometry.size.height)
                .contentLoadTransition(isLoaded: contentReady)
            }
        }
        .refreshable {
            await viewModel.loadDetail()
        }
        .sheet(isPresented: $showingRateSkill) {
            RateSkillView(
                skillName: skill.name,
                currentRating: viewModel.latestRating
            ) { rating, notes in
                await viewModel.saveRating(rating, notes: notes)
            }
        }
        .sheet(isPresented: $showingAddSubskill, onDismiss: {
            Task { await viewModel.loadDetail() }
        }) {
            AddEditSkillView(parentSkillId: skill.id)
        }
        .sheet(isPresented: $showingCoaching, onDismiss: {
            Task { await viewModel.loadDetail() }
        }) {
            SkillCoachingView(
                viewModel: SkillCoachingViewModel(
                    skill: skill,
                    subskills: viewModel.subskills,
                    subskillRatings: viewModel.subskillRatings,
                    currentRating: viewModel.latestRating,
                    existingDrills: viewModel.drills,
                    ratings: viewModel.ratings,
                    drillRepository: dependencies.drillRepository
                )
            )
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Delete Skill", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteSkill() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if viewModel.hasSubskills {
                Text("This will permanently delete \"\(skill.name)\" and all its subskills. This cannot be undone.")
            } else {
                Text("This will permanently delete \"\(skill.name)\". This cannot be undone.")
            }
        }
        .overlay {
            if viewModel.showCompletionCelebration {
                completionCelebration(viewModel)
            }
        }
        .overlay {
            if showingProgressCheckers {
                progressCheckersPopup(viewModel)
            }
        }
        .onChange(of: viewModel.showCompletionCelebration) { _, newValue in
            if newValue {
                withAnimation(AppAnimations.springBouncy) {
                    celebrationVisible = true
                }
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                celebrationVisible = false
            }
        }
    }

    // MARK: - Completion Celebration

    private func completionCelebration(_ viewModel: SkillDetailViewModel) -> some View {
        ZStack {
            AppColors.overlayScrim.opacity(celebrationVisible ? 0.5 : 0)
                .ignoresSafeArea()
                .animation(AppAnimations.fadeIn, value: celebrationVisible)

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColors.trophyGold)
                    .scaleEffect(celebrationVisible ? 1.0 : 0.6)

                Text("Skill Completed!")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(spacing: AppSpacing.xxxs) {
                    Text(skill.name)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("100%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }

                Text("You've mastered this skill!")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    viewModel.showCompletionCelebration = false
                    dismiss()
                } label: {
                    Text("Awesome!")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressable)
                .padding(.top, AppSpacing.xxs)
            }
            .padding(AppSpacing.xl)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(.horizontal, AppSpacing.xl)
            .scaleEffect(celebrationVisible ? 1.0 : 0.6)
            .opacity(celebrationVisible ? 1 : 0)
        }
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        let tier = SkillTier(rating: viewModel.latestRating)
        return VStack(spacing: AppSpacing.xs) {
            RatingBadge(rating: viewModel.latestRating, size: 160, ringColor: tier.color)
                .padding(.bottom, AppSpacing.xxs)

            Text(skill.name)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text(tier.displayName.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxxs)
                .background(tier.color.opacity(0.15))
                .clipShape(Capsule())

            HStack(spacing: AppSpacing.xxxs) {
                Text(viewModel.lastUpdatedText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let delta = viewModel.weeklyDelta, delta != 0 {
                    Text("·")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(delta > 0 ? AppColors.primary : AppColors.coral)

                    Text(delta > 0 ? "+\(delta)% this week" : "\(delta)% this week")
                        .font(AppTypography.caption)
                        .foregroundStyle(delta > 0 ? AppColors.primary : AppColors.coral)
                }
            }

            if !viewModel.hasSubskills && skill.status == .active {
                Button {
                    showingRateSkill = true
                } label: {
                    Text("Update Mastery")
                        .font(AppTypography.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, AppSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(skill.name), \(viewModel.latestRating) percent, \(tier.displayName)")
    }

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SUBSKILLS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if skill.status == .active {
                    Button {
                        showingAddSubskill = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Add Subskill")
                }
            }
            .padding(.bottom, AppSpacing.xs)

            if viewModel.subskills.isEmpty {
                Text("Break this skill into subskills to track progress in more detail.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.xxs)
            }

            ForEach(Array(viewModel.subskills.enumerated()), id: \.element.id) { index, subskill in
                let rating = viewModel.subskillRatings[subskill.id] ?? 0

                if index > 0 {
                    Divider()
                }

                NavigationLink(value: subskill) {
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                            Text(subskill.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            ProgressBar(progress: Double(rating) / 100.0, tint: SkillTier(rating: rating).color)
                        }

                        Text("\(rating)%")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(AppSpacing.sm)
    }

    // MARK: - Notes Section

    private func notesSection(_ viewModel: SkillDetailViewModel) -> some View {
        NavigationLink {
            SkillNotesView(
                notes: viewModel.skill.description
            ) { updatedNotes in
                await viewModel.updateNotes(updatedNotes)
            }
        } label: {
            HStack(spacing: 0) {
                // Teal accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.primary.opacity(0.4))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    HStack {
                        Text("MY NOTES")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                    }

                    if viewModel.skill.description.isEmpty {
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.primary.opacity(0.6))

                            Text("Tap to add notes about this skill...")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.top, AppSpacing.xxxs)
                    } else {
                        Text(viewModel.skill.description)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textPrimary.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.top, AppSpacing.xxxs)
                    }
                }
                .padding(.leading, AppSpacing.xs)
            }
            .padding(.vertical, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coaching Button

    @ViewBuilder
    private func coachingButton(_ viewModel: SkillDetailViewModel) -> some View {
        let hasPendingDrills = viewModel.drills.contains { $0.status == .pending }

        if skill.status == .active {
            if hasPendingDrills {
                // Subtle button when drills already exist
                Button {
                    showingCoaching = true
                } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)

                        Text("Get More Coaching")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                }
                .buttonStyle(.pressable)
            } else {
                // Prominent card when no drills exist
                Button {
                    showingCoaching = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                            Text("Get AI Coaching")
                                .font(AppTypography.headline)
                                .foregroundStyle(.white)

                            Text("Personalized drills & game tips")
                                .font(AppTypography.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(AppSpacing.sm)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: - Drills Section

    @State private var expandedDrillId: UUID?

    @ViewBuilder
    private func drillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        let pendingDrills = viewModel.drills.filter { $0.status == .pending }

        if !pendingDrills.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.caption)
                        .foregroundStyle(AppColors.primary)

                    Text("DRILLS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text("\(pendingDrills.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.bottom, AppSpacing.xs)

                ForEach(Array(pendingDrills.enumerated()), id: \.element.id) { index, drill in
                    if index > 0 {
                        Divider()
                    }

                    drillRow(drill, viewModel: viewModel)
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    private func drillRow(_ drill: Drill, viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Button {
                withAnimation(AppAnimations.springSmooth) {
                    expandedDrillId = expandedDrillId == drill.id ? nil : drill.id
                }
            } label: {
                HStack(alignment: .top, spacing: AppSpacing.xxs) {
                    Circle()
                        .fill(drill.priorityColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(drill.name)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.xxxs) {
                            Text("\(drill.durationMinutes) min")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            if let subskill = drill.targetSubskill {
                                Text("\u{2022}")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                Text(subskill.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.primary)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: expandedDrillId == drill.id ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if expandedDrillId == drill.id {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(drill.drillDescription)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))

                    Text(drill.reason)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .italic()

                    HStack(spacing: AppSpacing.xs) {
                        Button {
                            Task { await viewModel.updateDrillStatus(drill.id, status: .completed) }
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.successGreen)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.successGreen)

                        Button {
                            Task { await viewModel.updateDrillStatus(drill.id, status: .skipped) }
                        } label: {
                            Label("Skip", systemImage: "forward.fill")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.leading, 28)
                .padding(.top, AppSpacing.xxxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    // MARK: - Rating Notes Section

    @ViewBuilder
    private func ratingNotesSection(_ viewModel: SkillDetailViewModel) -> some View {
        let ratingsWithNotes = viewModel.ratings
            .filter { !($0.notes ?? "").isEmpty }
            .sorted { $0.date > $1.date }

        if !ratingsWithNotes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(AppAnimations.springSmooth) {
                        ratingNotesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(AppColors.primary)

                        Text("Rating Notes")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Text("\(ratingsWithNotes.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: ratingNotesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if ratingNotesExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(ratingsWithNotes) { rating in
                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                HStack {
                                    Text("\(rating.rating)%")
                                        .font(AppTypography.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColors.primary)

                                    Spacer()

                                    Text(rating.date, style: .date)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Text(rating.notes ?? "")
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(AppSpacing.xs)
                            .background(AppColors.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Progress Checkers Card

    private func progressCheckersCard(_ viewModel: SkillDetailViewModel) -> some View {
        Button {
            withAnimation(AppAnimations.springSmooth) {
                showingProgressCheckers = true
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Image(systemName: "checklist")
                        .font(.caption)
                        .foregroundStyle(AppColors.primary)

                    Text("PROGRESS")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text("\(viewModel.completedCheckersCount)/\(viewModel.progressCheckers.count)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                }

                ProgressBar(progress: viewModel.checkerProgress)

                // Show first 2 checkers as preview
                ForEach(viewModel.progressCheckers.prefix(2)) { checker in
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: checker.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(checker.isCompleted ? AppColors.successGreen : AppColors.lockedGray)

                        Text(checker.name)
                            .font(AppTypography.caption)
                            .foregroundStyle(checker.isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                            .lineLimit(1)
                    }
                }

                if viewModel.progressCheckers.count > 2 {
                    Text("+ \(viewModel.progressCheckers.count - 2) more")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Progress Checkers Popup

    @State private var progressPopupVisible = false

    private func progressCheckersPopup(_ viewModel: SkillDetailViewModel) -> some View {
        ZStack {
            // Blurred background scrim
            Color.clear
                .background(.ultraThinMaterial)
                .opacity(progressPopupVisible ? 1 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissProgressPopup()
                }

            // Popup card
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Progress")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Button {
                        dismissProgressPopup()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AppColors.separator)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.sm)

                Divider()
                    .padding(.horizontal, AppSpacing.lg)

                // Progress summary
                HStack(spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                        Text("\(viewModel.completedCheckersCount) of \(viewModel.progressCheckers.count) completed")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("\(Int(viewModel.checkerProgress * 100))% done")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    RatingBadge(
                        rating: Int(viewModel.checkerProgress * 100),
                        size: 48,
                        ringColor: AppColors.primary
                    )
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)

                ProgressBar(progress: viewModel.checkerProgress)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.sm)

                Divider()
                    .padding(.horizontal, AppSpacing.lg)

                // Checkers list
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.progressCheckers.enumerated()), id: \.element.id) { index, checker in
                            if index > 0 {
                                Divider()
                                    .padding(.leading, 52)
                            }

                            Button {
                                Task { await viewModel.toggleChecker(checker.id) }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    ZStack {
                                        Circle()
                                            .fill(checker.isCompleted ? AppColors.primary.opacity(0.12) : AppColors.separator.opacity(0.5))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: checker.isCompleted ? "checkmark" : "circle")
                                            .font(.system(size: checker.isCompleted ? 14 : 18, weight: .semibold))
                                            .foregroundStyle(checker.isCompleted ? AppColors.primary : AppColors.lockedGray)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(checker.name)
                                            .font(AppTypography.body)
                                            .foregroundStyle(checker.isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                                            .strikethrough(checker.isCompleted, color: AppColors.textSecondary)
                                            .multilineTextAlignment(.leading)

                                        if checker.isCompleted, let date = checker.completedDate {
                                            Text("Completed \(date, style: .relative) ago")
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, AppSpacing.xs)
                                .padding(.horizontal, AppSpacing.lg)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 30, y: 10)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 60)
            .scaleEffect(progressPopupVisible ? 1.0 : 0.92)
            .opacity(progressPopupVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                progressPopupVisible = true
            }
        }
    }

    private func dismissProgressPopup() {
        withAnimation(AppAnimations.springSmooth) {
            progressPopupVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showingProgressCheckers = false
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                showingDeleteConfirm = true
            } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "trash")
                    Text("Delete Skill")
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColors.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
            }
            .accessibilityLabel("Delete \(skill.name)")
        }
    }
}

#Preview {
    NavigationStack {
        SkillDetailView(skill: PreviewData.sampleServe)
    }
}
