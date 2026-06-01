import SwiftUI

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingAddSubskill = false
    @State private var showingDeleteConfirm = false
    @State private var showingCoaching = false
    @State private var showingProgressCheckers = false
    @State private var ratingNotesExpanded = false
    @State private var contentReady = false
    @State private var celebrationVisible = false
    @State private var sliderRating: Double = 0
    @State private var isEditingSlider = false
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
                VStack(spacing: AppSpacing.md) {
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
                .padding(.top, AppSpacing.xxxs)
                .frame(minHeight: geometry.size.height)
                .contentLoadTransition(isLoaded: contentReady)
            }
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .refreshable {
            await viewModel.loadDetail()
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
        .onChange(of: viewModel.latestRating) { _, newValue in
            if !isEditingSlider {
                sliderRating = Double(newValue)
            }
        }
        .onAppear {
            sliderRating = Double(viewModel.latestRating)
        }
    }

    // MARK: - Completion Celebration

    private func completionCelebration(_ viewModel: SkillDetailViewModel) -> some View {
        ZStack {
            AppColors.overlayScrim.opacity(celebrationVisible ? 0.5 : 0)
                .ignoresSafeArea()
                .animation(AppAnimations.fadeIn, value: celebrationVisible)

            VStack(spacing: AppSpacing.lg) {
                // Mascot celebration
                Text("\u{1F952}")
                    .font(.system(size: 56))
                    .scaleEffect(celebrationVisible ? 1.2 : 0.6)

                Text("Skill Mastered!")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColors.textPrimary)

                VStack(spacing: AppSpacing.xxxs) {
                    Text(skill.name)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("100%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.highlight)
                }

                Text("You crushed it! Time for the next challenge.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.showCompletionCelebration = false
                    dismiss()
                } label: {
                    Text("Let's go!")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            LinearGradient(
                                colors: [AppColors.highlight, AppColors.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
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
        let displayRating = isEditingSlider ? Int(sliderRating) : viewModel.latestRating
        let tier = SkillTier(rating: displayRating)
        return VStack(spacing: AppSpacing.xs) {
            // Compact hero: ring + title tightly grouped
            RatingBadge(rating: displayRating, size: 140, ringColor: tier.color)

            Text(skill.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .padding(.top, AppSpacing.xxxs)

            // Tier badge + metadata in one row
            HStack(spacing: AppSpacing.xxs) {
                // Premium tier badge
                HStack(spacing: 4) {
                    Image(systemName: tier.sfSymbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(tier.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(tier.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tier.color.opacity(0.12))
                .clipShape(Capsule())

                if let delta = viewModel.weeklyDelta, delta != 0 {
                    HStack(spacing: 3) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))

                        Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(delta > 0 ? AppColors.highlight : AppColors.coral)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background((delta > 0 ? AppColors.highlight : AppColors.coral).opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(viewModel.lastUpdatedText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Skill level slider
            if !viewModel.hasSubskills && skill.status == .active {
                skillLevelSlider(displayRating: displayRating, tier: tier, viewModel: viewModel)
                    .padding(.top, AppSpacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(skill.name), \(displayRating) percent, \(tier.displayName)")
    }

    // MARK: - Skill Level Slider

    private func skillLevelSlider(displayRating: Int, tier: SkillTier, viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            // Custom styled slider
            Slider(
                value: $sliderRating,
                in: 0...100,
                step: 1
            ) {
                Text("Rating")
            } onEditingChanged: { editing in
                isEditingSlider = editing
                if editing {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
                if !editing {
                    let newRating = Int(sliderRating)
                    if newRating != viewModel.latestRating {
                        Task { _ = await viewModel.saveRating(newRating, notes: nil) }
                    }
                }
            }
            .tint(tier.color)
            .onAppear {
                // Match max track to ring track so both sides of the thumb look unified
                UISlider.appearance().maximumTrackTintColor = UIColor(AppColors.ringTrack)
            }

            // Milestone labels
            HStack {
                ForEach(Array(SkillTier.allCases.enumerated()), id: \.element) { index, milestone in
                    Text(milestone.displayName)
                        .font(.system(size: 9, weight: tier == milestone ? .bold : .medium, design: .rounded))
                        .foregroundStyle(tier == milestone ? tier.color : AppColors.textSecondary.opacity(0.6))
                    if index < SkillTier.allCases.count - 1 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)

            // Next tier prompt
            if let nextTier = tier.nextTier {
                let pointsNeeded = SkillTier.pointsToNext(for: displayRating)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.highlight)

                    Text("\(pointsNeeded) pts to \(nextTier.displayName)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, AppSpacing.xxs)
    }

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.primaryLight)

                    Text("SUBSKILLS")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if skill.status == .active {
                    Button {
                        showingAddSubskill = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("Add Subskill")
                }
            }
            .padding(.bottom, AppSpacing.xs)

            if viewModel.subskills.isEmpty {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "arrow.branch")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.primaryLight)

                    Text("Break this skill into subskills to track progress in detail")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.vertical, AppSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(AppColors.primaryTint.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(SkillTier(rating: rating).color)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.pressable)
            }
        }
        .infoCard()
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
                // Accent bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.highlight, AppColors.primaryLight],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 5)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.primaryLight)

                            Text("MY NOTES")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.primary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                    }

                    if viewModel.skill.description.isEmpty {
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 15))
                                .foregroundStyle(AppColors.primaryLight.opacity(0.7))

                            Text("Tap to jot down thoughts about this skill...")
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.top, AppSpacing.xxxs)
                    } else {
                        Text(viewModel.skill.description)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .padding(.top, AppSpacing.xxxs)
                    }
                }
                .padding(.leading, AppSpacing.xs)
            }
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.sm)
            .background(AppColors.notesCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
                    .stroke(AppColors.primaryLight.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Coaching Button

    @ViewBuilder
    private func coachingButton(_ viewModel: SkillDetailViewModel) -> some View {
        let hasPendingDrills = viewModel.drills.contains { $0.status == .pending }

        if skill.status == .active {
            if hasPendingDrills {
                Button {
                    showingCoaching = true
                } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(AppColors.primaryLight)

                        Text("Get More Coaching")
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.coachCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall)
                            .stroke(AppColors.coachCardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.pressable)
            } else {
                // Prominent coaching card -- highest emphasis
                Button {
                    showingCoaching = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Get AI Coaching")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Personalized drills & game tips")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        LinearGradient(
                            colors: [AppColors.primary, Color(hex: "2A4935")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    .shadow(color: AppColors.primary.opacity(0.3), radius: 8, y: 4)
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
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.primaryLight)

                        Text("DRILLS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("\(pendingDrills.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.primaryTint)
                        .clipShape(Capsule())
                }
                .padding(.bottom, AppSpacing.xs)

                ForEach(Array(pendingDrills.enumerated()), id: \.element.id) { index, drill in
                    if index > 0 {
                        Divider()
                    }

                    drillRow(drill, viewModel: viewModel)
                }
            }
            .infoCard()
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
                                    .foregroundStyle(AppColors.primaryLight)
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
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.primaryLight)

                            Text("Rating Notes")
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                        }

                        Spacer()

                        Text("\(ratingsWithNotes.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppColors.primaryTint)
                            .clipShape(Capsule())

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
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(SkillTier(rating: rating.rating).color)

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
            .infoCard()
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
                    HStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.primaryLight)

                        Text("PROGRESS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text("\(viewModel.completedCheckersCount)/\(viewModel.progressCheckers.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                }

                ProgressBar(progress: viewModel.checkerProgress)

                ForEach(viewModel.progressCheckers.prefix(2)) { checker in
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: checker.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 14))
                            .foregroundStyle(checker.isCompleted ? AppColors.highlight : AppColors.lockedGray)

                        Text(checker.name)
                            .font(AppTypography.caption)
                            .foregroundStyle(checker.isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                            .lineLimit(1)
                    }
                }

                if viewModel.progressCheckers.count > 2 {
                    Text("+ \(viewModel.progressCheckers.count - 2) more")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primaryLight)
                }
            }
            .infoCard()
        }
        .buttonStyle(.pressable)
    }

    // MARK: - Progress Checkers Popup

    @State private var progressPopupVisible = false

    private func progressCheckersPopup(_ viewModel: SkillDetailViewModel) -> some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .opacity(progressPopupVisible ? 1 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissProgressPopup()
                }

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
                                            .fill(checker.isCompleted ? AppColors.highlight.opacity(0.15) : AppColors.separator.opacity(0.5))
                                            .frame(width: 36, height: 36)

                                        Image(systemName: checker.isCompleted ? "checkmark" : "circle")
                                            .font(.system(size: checker.isCompleted ? 14 : 18, weight: .semibold))
                                            .foregroundStyle(checker.isCompleted ? AppColors.highlight : AppColors.lockedGray)
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
