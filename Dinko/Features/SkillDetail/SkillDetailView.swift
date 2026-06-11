import SwiftUI

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingAddSubskill = false
    @State private var showingDeleteConfirm = false
    @State private var showingProgressCheckers = false
    @State private var showingConfidenceUpdate = false
    @State private var inlineCoachingVM: SkillCoachingViewModel?
    @State private var contentReady = false
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
                    confidenceEntryRepository: dependencies.confidenceEntryRepository,
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
                    confidenceHero(viewModel)

                    if viewModel.isLocked {
                        lockedCallout(viewModel)
                    } else if viewModel.confidenceGap > 0 {
                        gapCallout(viewModel)
                    }

                    updateConfidenceButton(viewModel)

                    coachingCard(viewModel)

                    if let why = viewModel.whyItMatters {
                        whyItMattersCard(why)
                    }

                    if !viewModel.prerequisiteFor.isEmpty {
                        prereqForCard(viewModel)
                    }

                    if viewModel.isParentSkill {
                        subskillsSection(viewModel)
                    }

                    if !viewModel.progressCheckers.isEmpty {
                        progressCheckersCard(viewModel)
                    }

                    notesSection(viewModel)

                    confidenceHistorySection(viewModel)

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
        .sheet(isPresented: $showingConfidenceUpdate) {
            ConfidenceUpdateSheet(
                skillName: skill.name,
                currentConfidence: viewModel.currentConfidence
            ) { newConfidence in
                Task { await viewModel.saveConfidence(newConfidence) }
            }
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
            if showingProgressCheckers {
                progressCheckersPopup(viewModel)
            }
        }
    }

    // MARK: - Confidence Hero

    private func confidenceHero(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.sm) {
            // Pillar icon + name
            HStack(spacing: AppSpacing.xxs) {
                Text(skill.pillar.iconName)
                    .font(.title3)
                Text(skill.pillar.displayName)
                    .font(AppTypography.pillLabel)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.top, AppSpacing.md)

            // Skill name
            Text(skill.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)

            // Confidence display
            HStack(spacing: AppSpacing.xxs) {
                Text("\(viewModel.currentConfidence)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
                Text("/ 10")
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .offset(y: 8)
            }

            // Confidence bar
            if let target = viewModel.targetConfidence {
                ConfidenceBar(current: viewModel.currentConfidence, target: target)
                    .padding(.horizontal, AppSpacing.md)
            }

            // Last updated
            Text(viewModel.lastUpdatedText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .neumorphicRaised(intensity: .prominent, cornerRadius: AppSpacing.heroCornerRadius)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(skill.name), confidence \(viewModel.currentConfidence) of 10")
    }

    // MARK: - Gap / Locked Callouts

    @ViewBuilder
    private func gapCallout(_ viewModel: SkillDetailViewModel) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "target")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.coral)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.confidenceGap) point\(viewModel.confidenceGap == 1 ? "" : "s") below target")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                if let target = viewModel.targetConfidence {
                    Text("Target: \(target) for your goal DUPR")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.coral.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    @ViewBuilder
    private func lockedCallout(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.warningOrange)
                Text("Skill Locked")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }

            ForEach(viewModel.unmetPrereqs, id: \.requiredCanonicalId) { prereq in
                if let canonical = CanonicalSkill.find(prereq.requiredCanonicalId) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                            .font(.system(size: 8))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(canonical.name) needs confidence \(prereq.requiredConfidence)+")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.warningOrange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Update Confidence Button

    private func updateConfidenceButton(_ viewModel: SkillDetailViewModel) -> some View {
        Button {
            showingConfidenceUpdate = true
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                Text("Update Confidence")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.primaryTint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLocked)
        .opacity(viewModel.isLocked ? 0.5 : 1)
    }

    // MARK: - Why It Matters

    private func whyItMattersCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Why This Matters")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(text)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
    }

    // MARK: - Prerequisite For

    private func prereqForCard(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Unlocks")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }

            ForEach(viewModel.prerequisiteFor, id: \.self) { name in
                HStack(spacing: 6) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.successGreen)
                    Text(name)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
    }

    // MARK: - Confidence History

    @ViewBuilder
    private func confidenceHistorySection(_ viewModel: SkillDetailViewModel) -> some View {
        if viewModel.confidenceHistory.count >= 2 {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("Confidence History")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

                Divider().padding(.horizontal, AppSpacing.sm)

                // Simple list of recent entries
                ForEach(viewModel.confidenceHistory.suffix(10).reversed()) { entry in
                    HStack {
                        Text("\(entry.confidence)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.source.displayLabel)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                            Text(entry.date, style: .date)
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xxs)
                }
                .padding(.bottom, AppSpacing.xs)
            }
            .neumorphicRaised(cornerRadius: AppSpacing.cardCornerRadius)
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
                        .neumorphicTinted(color: AppColors.successGreen, cornerRadius: AppSpacing.cornerRadiusMd)
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
                                            Text("\u{2022}").foregroundStyle(AppColors.textSecondary)
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

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: 0) {
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
                        Text("Tap to add notes about this skill...")
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
