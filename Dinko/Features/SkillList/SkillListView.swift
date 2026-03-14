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
                        .staggeredAppearance(index: index + 1)
                    }
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

        return HStack(spacing: AppSpacing.sm) {
            RatingBadge(rating: avgRating, size: 72, ringColor: avgTier.color)

            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR LEVEL")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(avgTier.displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    if let next = avgTier.nextTier {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(next.displayName)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppColors.textSecondary)
                    }
                }

                // Overall tier progress bar
                OverviewTierBar(rating: avgRating, tier: avgTier)

                HStack(spacing: AppSpacing.xs) {
                    statPill(
                        icon: "figure.pickleball",
                        value: "\(viewModel.skills.count)",
                        label: "skills"
                    )

                    if improvingCount > 0 {
                        statPill(
                            icon: "arrow.up.right",
                            value: "\(improvingCount)",
                            label: "improving",
                            color: AppColors.successGreen
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func statPill(icon: String, value: String, label: String, color: Color = AppColors.teal) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text("\(value) \(label)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Skills Yet",
            systemImage: "figure.pickleball",
            description: Text("Add your first skill to start tracking your progress.")
        )
    }
}

// MARK: - Overview Tier Progress Bar

private struct OverviewTierBar: View {
    let rating: Int
    let tier: SkillTier

    @State private var animatedProgress: Double = 0

    private var tierProgress: Double { SkillTier.tierProgress(for: rating) }
    private var pointsToNext: Int { SkillTier.pointsToNext(for: rating) }

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tier.color.opacity(0.12))

                    Capsule()
                        .fill(tier.color.gradient)
                        .frame(width: max(geo.size.width * animatedProgress, 0))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            if tier.nextTier != nil {
                Text("\(pointsToNext) pts")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize()
            }
        }
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
