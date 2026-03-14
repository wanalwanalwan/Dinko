import SwiftUI

struct SkillListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: SkillListViewModel?
    @State private var showingAddSkill = false
    @State private var contentReady = false

    var body: some View {
        Group {
            if let viewModel {
                skillListContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("My Progress")
        .navigationDestination(for: Skill.self) { skill in
            SkillDetailView(skill: skill)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSkill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSkill, onDismiss: {
            if let viewModel {
                Task { await viewModel.loadSkills() }
            }
        }) {
            AddEditSkillView()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .task {
            if viewModel == nil {
                let vm = SkillListViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadSkills()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadSkills() }
            }
        }
    }

    @ViewBuilder
    private func skillListContent(_ viewModel: SkillListViewModel) -> some View {
        if viewModel.skills.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    overviewCard(viewModel)
                        .staggeredAppearance(index: 0)

                    // Grouped skills card
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.skills.enumerated()), id: \.element.id) { index, skill in
                            NavigationLink(value: skill) {
                                SkillCard(
                                    skill: skill,
                                    subskillCount: viewModel.subskillCounts[skill.id] ?? 0,
                                    rating: viewModel.latestRatings[skill.id] ?? 0,
                                    delta: viewModel.ratingDeltas[skill.id]
                                )
                            }
                            .buttonStyle(.pressable)

                            if index < viewModel.skills.count - 1 {
                                Divider()
                                    .padding(.leading, 34) // align with skill name
                            }
                        }
                    }
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .staggeredAppearance(index: 1)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xl)
                .contentLoadTransition(isLoaded: contentReady)
            }
            .refreshable {
                await viewModel.loadSkills()
            }
        }
    }

    // MARK: - Overview Card

    private func overviewCard(_ viewModel: SkillListViewModel) -> some View {
        let ratings = viewModel.skills.map { viewModel.latestRatings[$0.id] ?? 0 }
        let avgRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / ratings.count
        let improvingCount = viewModel.ratingDeltas.values.filter { $0 > 0 }.count
        let avgTier = SkillTier(rating: avgRating)
        let tierLevel = SkillTier.allCases.firstIndex(of: avgTier).map { $0 + 1 } ?? 1

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Level label
            Text("LEVEL \(tierLevel)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(avgTier.color)
                .tracking(1)

            // Tier name
            Text(avgTier.displayName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            // Progress to next tier
            if let next = avgTier.nextTier {
                let pointsToNext = SkillTier.pointsToNext(for: avgRating)
                Text("\(pointsToNext) pts to \(next.displayName)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            // Tier progress bar
            OverviewTierBar(rating: avgRating, tier: avgTier)

            // Stats
            Text("\(viewModel.skills.count) skills \u{00B7} \(improvingCount) improving")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, AppSpacing.xxxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Skills Yet")
            } icon: {
                CoachMascot(state: .idle, size: 48, animated: false)
            }
        } description: {
            Text("Add your first skill to start tracking your progress.")
        }
    }
}

// MARK: - Overview Tier Progress Bar

private struct OverviewTierBar: View {
    let rating: Int
    let tier: SkillTier

    @State private var animatedProgress: Double = 0

    private var tierProgress: Double { SkillTier.tierProgress(for: rating) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tier.color.opacity(0.12))

                Capsule()
                    .fill(tier.color.gradient)
                    .frame(width: max(geo.size.width * animatedProgress, 0))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .onAppear {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = tierProgress
            }
        }
        .onChange(of: rating) {
            withAnimation(AppAnimations.springSmooth) {
                animatedProgress = tierProgress
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkillListView()
    }
}
