import SwiftUI

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingAddSubskill = false
    @State private var showingDeleteConfirm = false
    @State private var showingProgressCheckers = false
    @State private var inlineCoachingVM: SkillCoachingViewModel?
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

                    benchmarkComparison(viewModel)

                    coachingCard(viewModel)

                    if viewModel.isParentSkill {
                        subskillsSection(viewModel)
                    }

                    if !viewModel.progressCheckers.isEmpty {
                        progressCheckersCard(viewModel)
                    }

                    notesSection(viewModel)
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
            // Blurred backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(celebrationVisible ? 1 : 0)
                .animation(AppAnimations.fadeIn, value: celebrationVisible)

            VStack(spacing: 0) {
                // Emoji + pulse rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(AppColors.highlight.opacity(0.12 - Double(i) * 0.03),
                                    lineWidth: 1.5)
                            .frame(width: CGFloat(80 + i * 30), height: CGFloat(80 + i * 30))
                            .scaleEffect(celebrationVisible ? 1 : 0.3)
                            .opacity(celebrationVisible ? 1 : 0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.6)
                                    .delay(0.1 + Double(i) * 0.08),
                                value: celebrationVisible
                            )
                    }
                    Circle()
                        .fill(AppColors.highlight.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Text("🥒")
                        .font(.system(size: 38))
                        .scaleEffect(celebrationVisible ? 1.0 : 0.3)
                        .animation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.05),
                                   value: celebrationVisible)
                }
                .padding(.bottom, AppSpacing.md)

                // "Mastered" pill
                Label("Skill Mastered", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.highlight)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(AppColors.highlight.opacity(0.12))
                    .clipShape(Capsule())
                    .opacity(celebrationVisible ? 1 : 0)
                    .offset(y: celebrationVisible ? 0 : 10)
                    .animation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.15),
                               value: celebrationVisible)
                    .padding(.bottom, AppSpacing.xs)

                // Skill name
                Text(skill.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(celebrationVisible ? 1 : 0)
                    .offset(y: celebrationVisible ? 0 : 12)
                    .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(0.20),
                               value: celebrationVisible)
                    .padding(.bottom, 4)

                // 100%
                Text("100%")
                    .font(Font.custom("Sora-Bold", size: 42))
                    .foregroundStyle(AppColors.highlight)
                    .opacity(celebrationVisible ? 1 : 0)
                    .offset(y: celebrationVisible ? 0 : 10)
                    .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(0.25),
                               value: celebrationVisible)
                    .padding(.bottom, AppSpacing.sm)

                // Body
                Text("You mastered this skill.\nTime for the next challenge.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(celebrationVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.35).delay(0.30),
                               value: celebrationVisible)
                    .padding(.bottom, AppSpacing.lg)

                // CTA
                Button {
                    viewModel.showCompletionCelebration = false
                    dismiss()
                } label: {
                    Text("Let's go! 🎉")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            ZStack {
                                LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDark],
                                               startPoint: .top, endPoint: .bottom)
                                LinearGradient(colors: [.white.opacity(0.16), .clear],
                                               startPoint: .top,
                                               endPoint: .init(x: 0.5, y: 0.55))
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppColors.primary.opacity(0.30), radius: 0, y: 3)
                        .shadow(color: AppColors.primary.opacity(0.14), radius: 8, y: 5)
                }
                .buttonStyle(.pressable)
                .opacity(celebrationVisible ? 1 : 0)
                .offset(y: celebrationVisible ? 0 : 16)
                .animation(.spring(response: 0.45, dampingFraction: 0.78).delay(0.35),
                           value: celebrationVisible)
            }
            .padding(AppSpacing.lg)
            .padding(.top, AppSpacing.sm)
            .background(
                ZStack {
                    AppColors.background
                    // Subtle green glow at top
                    LinearGradient(
                        colors: [AppColors.highlight.opacity(0.08), .clear],
                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.45)
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: AppColors.neumorphicDark.opacity(0.6), radius: 24, x: 6, y: 8)
            .shadow(color: AppColors.neumorphicLight.opacity(0.4), radius: 12, x: -4, y: -4)
            .padding(.horizontal, AppSpacing.lg)
            .scaleEffect(celebrationVisible ? 1.0 : 0.75)
            .opacity(celebrationVisible ? 1 : 0)
            .animation(.spring(response: 0.48, dampingFraction: 0.70), value: celebrationVisible)
        }
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        let displayRating = isEditingSlider ? Int(sliderRating) : viewModel.latestRating
        let tier = SkillTier(rating: displayRating)
        return VStack(spacing: 0) {

            // Ring — centred, generous top spacing
            RatingBadge(rating: displayRating, size: 158, ringColor: tier.color)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            // Skill name
            Text(skill.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xs)

            // Tier + delta + date — one tight row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: tier.sfSymbol)
                        .font(.system(size: 10, weight: .semibold))
                    Text(tier.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(tier.color)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(tier.color.opacity(0.11))
                .clipShape(Capsule())

                if let delta = viewModel.weeklyDelta, delta != 0 {
                    HStack(spacing: 3) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(delta > 0 ? AppColors.highlight : AppColors.coral)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background((delta > 0 ? AppColors.highlight : AppColors.coral).opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(viewModel.lastUpdatedText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.md)

            // Divider before slider
            if !viewModel.hasSubskills && skill.status == .active {
                Divider().padding(.horizontal, AppSpacing.md)
                skillLevelSlider(displayRating: displayRating, tier: tier, viewModel: viewModel)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .neumorphicRaised(intensity: .prominent, cornerRadius: AppSpacing.heroCornerRadius)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(skill.name), \(displayRating) percent, \(tier.displayName)")
    }

    // MARK: - Skill Level Slider

    private func skillLevelSlider(displayRating: Int, tier: SkillTier, viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            PremiumRatingSlider(
                value: $sliderRating,
                showLevelLabel: false,
                showRails: false,
                onCommit: { newValue in
                    isEditingSlider = false
                    let newRating = Int(newValue)
                    if newRating != viewModel.latestRating {
                        Task { _ = await viewModel.saveRating(newRating, notes: nil) }
                    }
                }
            )
            .onChange(of: sliderRating) { isEditingSlider = true }

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

            // Complete Skill button — appears when slider reaches 100
            if displayRating == 100 {
                Button {
                    Task { _ = await viewModel.saveRating(100, notes: nil) }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Complete Skill")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        ZStack {
                            LinearGradient(colors: [AppColors.highlight, AppColors.successGreenDark],
                                           startPoint: .top, endPoint: .bottom)
                            LinearGradient(colors: [.white.opacity(0.16), .clear],
                                           startPoint: .top,
                                           endPoint: .init(x: 0.5, y: 0.55))
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .shadow(color: AppColors.highlight.opacity(0.35), radius: 0, y: 3)
                    .shadow(color: AppColors.highlight.opacity(0.18), radius: 8, y: 5)
                }
                .buttonStyle(.pressable)
                .padding(.top, AppSpacing.xs)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: displayRating == 100)
        .padding(.horizontal, AppSpacing.xxs)
    }

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: 0) {
            // Alma-style card header
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("Subskills")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                if skill.status == .active {
                    Button { showingAddSubskill = true } label: {
                        ZStack {
                            Circle()
                                .fill(AppColors.separator.opacity(0.4))
                                .frame(width: 30, height: 30)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
                    .accessibilityLabel("Add Subskill")
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider().padding(.horizontal, AppSpacing.sm)

            if viewModel.subskills.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.branch")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.primary.opacity(0.3))
                    Text("Break this skill into subskills\nto track progress in detail")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            }

            ForEach(Array(viewModel.subskills.enumerated()), id: \.element.id) { index, subskill in
                let rating = viewModel.subskillRatings[subskill.id] ?? 0
                if index > 0 { Divider().padding(.horizontal, AppSpacing.sm) }
                NavigationLink(value: subskill) {
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(subskill.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            ProgressBar(progress: Double(rating) / 100.0,
                                        tint: SkillTier(rating: rating).color)
                        }
                        Spacer()
                        Text("\(rating)%")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(SkillTier(rating: rating).color)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.35))
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.pressable)
            }
        }
        .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
    }

    // MARK: - Notes Section

    private func notesSection(_ viewModel: SkillDetailViewModel) -> some View {
        NavigationLink {
            SkillNotesView(notes: viewModel.skill.description) { updatedNotes in
                await viewModel.updateNotes(updatedNotes)
            }
        } label: {
            VStack(spacing: 0) {
                // Alma-style card header
                HStack {
                    HStack(spacing: 7) {
                        Image(systemName: "note.text")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                        Text("My Notes")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

                Divider().padding(.horizontal, AppSpacing.sm)

                if viewModel.skill.description.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                        Text("Tap to add notes about this skill…")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.md)
                } else {
                    Text(viewModel.skill.description)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.sm)
                }
            }
            .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Benchmark Comparison

    @ViewBuilder
    private func benchmarkComparison(_ viewModel: SkillDetailViewModel) -> some View {
        if let result = SkillBenchmark.comparison(userRating: viewModel.latestRating, category: viewModel.skill.category) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: result.delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(result.delta >= 0 ? AppColors.successGreen : AppColors.coral)

                Text("Players at your level average \(result.benchmark)% on \(viewModel.skill.category.displayName)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                let deltaText = result.delta >= 0 ? "+\(result.delta)" : "\(result.delta)"
                let deltaColor = result.delta >= 0 ? AppColors.successGreen : AppColors.coral
                Text(deltaText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(deltaColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(deltaColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
    }

    // MARK: - Inline Coaching Card

    @ViewBuilder
    private func coachingCard(_ detailVM: SkillDetailViewModel) -> some View {
        if skill.status == .active {
            if let coachVM = inlineCoachingVM {
                Group {
                    if coachVM.isLoading {
                        inlineLoadingCard
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                                removal: .opacity
                            ))
                    } else if let err = coachVM.errorMessage,
                              coachVM.gameTips.isEmpty && coachVM.drills.isEmpty {
                        inlineErrorCard(err, coachVM: coachVM)
                            .transition(.opacity)
                    } else {
                        inlineResultsCard(coachVM, detailVM: detailVM)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97, anchor: .top)),
                                removal: .opacity
                            ))
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: coachVM.isLoading)
            } else {
                let hasPendingDrills = detailVM.drills.contains { $0.status == .pending }
                if hasPendingDrills {
                    Button {
                        startInlineCoaching(detailVM)
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
                    Button {
                        startInlineCoaching(detailVM)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.18))
                                    .frame(width: 46, height: 46)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Get AI Coaching")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Personalized drills & game tips")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                            Spacer()
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            ZStack {
                                LinearGradient(
                                    colors: [AppColors.primaryLight, AppColors.primaryDark],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                                LinearGradient(
                                    colors: [.white.opacity(0.14), .clear],
                                    startPoint: .top,
                                    endPoint: .init(x: 0.5, y: 0.55)
                                )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                        .shadow(
                            color: AppColors.neumorphicLight.opacity(0.5),
                            radius: 6, x: -4, y: -4
                        )
                        .shadow(
                            color: AppColors.neumorphicDark.opacity(0.5),
                            radius: 6, x: 4, y: 4
                        )
                        .shadow(color: AppColors.primary.opacity(0.25), radius: 8, y: 4)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private func startInlineCoaching(_ detailVM: SkillDetailViewModel) {
        let vm = SkillCoachingViewModel(
            skill: skill,
            subskills: detailVM.subskills,
            subskillRatings: detailVM.subskillRatings,
            currentRating: detailVM.latestRating,
            existingDrills: detailVM.drills,
            ratings: detailVM.ratings,
            drillRepository: dependencies.drillRepository
        )
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            inlineCoachingVM = vm
        }
        Task { await vm.generateCoaching() }
    }

    // MARK: - Loading card

    private var inlineLoadingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Premium", systemImage: "star.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.trophyGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.trophyGold.opacity(0.13))
                .clipShape(Capsule())

            HStack(spacing: 10) {
                ProgressView()
                    .scaleEffect(0.85)
                    .tint(AppColors.textSecondary)
                Text("Checking your goals...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neumorphicRaised(intensity: .prominent, cornerRadius: AppSpacing.cardCornerRadius)
        .shadow(color: AppColors.trophyGold.opacity(0.18), radius: 12, y: 4)
    }

    // MARK: - Error card

    private func inlineErrorCard(_ message: String, coachVM: SkillCoachingViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(AppColors.coral)
            Text(message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
            Spacer()
            Button {
                Task { await coachVM.generateCoaching() }
            } label: {
                Text("Retry")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.sm)
        .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cardCornerRadius)
    }

    // MARK: - Results card

    private func inlineResultsCard(_ coachVM: SkillCoachingViewModel, detailVM: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Label("AI Coaching", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
                Spacer()
                Button {
                    Task {
                        await coachVM.generateCoaching()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        inlineCoachingVM = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(6)
                        .background(AppColors.separator.opacity(0.4))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            if !coachVM.gameTips.isEmpty {
                Divider().padding(.horizontal, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: 5) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.warningOrange)
                        Text("GAME TIPS")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.xs)

                    ForEach(coachVM.gameTips) { tip in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tip.title)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(tip.tip)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                                .lineSpacing(2)
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.warningOrange)
                                Text(tip.situation)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, AppSpacing.xs)
                    }
                }
                .padding(.bottom, AppSpacing.xs)
            }

            if !coachVM.drills.isEmpty {
                Divider().padding(.horizontal, AppSpacing.sm)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: 5) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.primary)
                        Text("DRILL SUGGESTIONS")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.xs)

                    ForEach(Array(coachVM.drills.enumerated()), id: \.element.name) { index, drill in
                        let isAdded = coachVM.addedDrillIndices.contains(index)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(drill.name)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(AppColors.textPrimary)
                                    HStack(spacing: 4) {
                                        Text("\(drill.durationMinutes) min")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(AppColors.textSecondary)
                                        if let sub = drill.targetSubskill {
                                            Text("•").foregroundStyle(AppColors.textSecondary)
                                            Text(sub)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(AppColors.primary)
                                        }
                                    }
                                }
                                Spacer()
                                Button {
                                    Task {
                                        await coachVM.addDrill(at: index)
                                        await detailVM.loadDetail()
                                    }
                                } label: {
                                    if isAdded {
                                        Label("Added", systemImage: "checkmark.circle.fill")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(AppColors.successGreen)
                                    } else {
                                        Label("Add", systemImage: "plus.circle.fill")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(AppColors.primary)
                                    }
                                }
                                .disabled(isAdded)
                                .buttonStyle(.pressable)
                            }
                            Text(drill.reason)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                                .italic()
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.background.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, AppSpacing.xs)
                    }
                }
                .padding(.bottom, AppSpacing.sm)
            }
        }
        .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
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
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppColors.neumorphicDark.opacity(0.6), radius: 20, x: 6, y: 10)
            .shadow(color: AppColors.neumorphicLight.opacity(0.4), radius: 12, x: -4, y: -4)
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
