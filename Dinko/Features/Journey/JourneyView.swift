import SwiftUI

struct JourneyView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel = JourneyViewModel()
    @State private var selectedSkillId: UUID?
    @State private var showConfidenceUpdate = false
    @State private var updateSkillName: String = ""
    @State private var updateSkillConfidence: Int = 1
    @State private var updateSkillId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                goalHeader
                bottleneckCallout
                pillarOverview
                pillarSections
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadJourney()
        }
        .task {
            viewModel.skillRepository = dependencies.skillRepository
            viewModel.confidenceEntryRepository = dependencies.confidenceEntryRepository
            viewModel.focusHistoryRepository = dependencies.focusHistoryRepository
            await viewModel.loadJourney()
        }
        .sheet(isPresented: $showConfidenceUpdate) {
            ConfidenceUpdateSheet(
                skillName: updateSkillName,
                currentConfidence: updateSkillConfidence,
                onSave: { newConfidence in
                    Task { await saveConfidenceUpdate(newConfidence) }
                }
            )
        }
    }

    // MARK: - Goal Header

    private var goalHeader: some View {
        RoadToGoalBar(
            skillsAtTarget: viewModel.skillsAtTarget,
            totalSkills: viewModel.totalTrackableSkills,
            goalDUPR: viewModel.goalDUPR
        )
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: - Bottleneck Callout

    @ViewBuilder
    private var bottleneckCallout: some View {
        if !viewModel.bottleneckNarrative.isEmpty {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.warningOrange)

                Text(viewModel.bottleneckNarrative)
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(AppSpacing.sm)
            .neumorphicTinted(color: AppColors.warningOrange, tintOpacity: 0.04, borderOpacity: 0.15)
        }
    }

    // MARK: - Pillar Overview Grid

    private var pillarOverview: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: AppSpacing.xxs),
            GridItem(.flexible(), spacing: AppSpacing.xxs),
            GridItem(.flexible(), spacing: AppSpacing.xxs)
        ], spacing: AppSpacing.xxs) {
            ForEach(viewModel.pillarSummaries) { summary in
                PillarCard(
                    summary: summary,
                    isExpanded: viewModel.expandedPillars.contains(summary.pillar),
                    onTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.togglePillar(summary.pillar)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Expandable Pillar Sections

    private var pillarSections: some View {
        ForEach(SkillPillar.allCases) { pillar in
            let isExpanded = viewModel.expandedPillars.contains(pillar)
            let skills = viewModel.skillsByPillar[pillar] ?? []

            if !skills.isEmpty {
                VStack(spacing: 0) {
                    // Section header
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.togglePillar(pillar)
                        }
                    } label: {
                        HStack {
                            Text(pillar.iconName)
                                .font(.body)
                            Text(pillar.displayName)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()

                            let atTarget = skills.filter { $0.gap == 0 }.count
                            Text("\(atTarget)/\(skills.count)")
                                .font(AppTypography.cardCaption)
                                .foregroundStyle(AppColors.textSecondary)

                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        // Column headers
                        HStack(spacing: AppSpacing.xxs) {
                            Text("Skill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("You")
                                .frame(width: 30, alignment: .center)
                            Text(viewModel.goalDUPR)
                                .frame(width: 30, alignment: .center)
                            Text("Gap")
                                .frame(width: 30, alignment: .center)
                            Color.clear.frame(width: 36)
                        }
                        .font(AppTypography.pillLabel)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, 4)

                        // Skill rows
                        ForEach(skills) { skillInfo in
                            SkillConfidenceRow(info: skillInfo) {
                                if !skillInfo.isLocked {
                                    updateSkillId = skillInfo.id
                                    updateSkillName = skillInfo.name
                                    updateSkillConfidence = skillInfo.currentConfidence
                                    showConfidenceUpdate = true
                                }
                            }

                            if skillInfo.id != skills.last?.id {
                                Divider()
                                    .padding(.horizontal, AppSpacing.sm)
                            }
                        }
                    }
                }
                .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)
            }
        }
    }

    // MARK: - Save Confidence Update

    private func saveConfidenceUpdate(_ newConfidence: Int) async {
        guard let skillId = updateSkillId else { return }

        let entry = ConfidenceEntry(
            skillId: skillId,
            confidence: newConfidence,
            source: .manual
        )

        do {
            try await dependencies.confidenceEntryRepository.save(entry)
            await viewModel.loadJourney()
        } catch {
            #if DEBUG
            print("JourneyView.saveConfidenceUpdate error: \(error)")
            #endif
        }
    }
}
