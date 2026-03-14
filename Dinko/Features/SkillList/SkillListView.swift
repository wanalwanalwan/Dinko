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
                    // Summary card
                    overviewCard(viewModel)
                        .staggeredAppearance(index: 0)

                    // Skill cards
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

        return HStack(spacing: 0) {
            overviewStat(
                value: "\(viewModel.skills.count)",
                label: "Skills",
                icon: "figure.pickleball"
            )

            divider

            overviewStat(
                value: "\(avgRating)%",
                label: "Average",
                icon: "chart.bar.fill"
            )

            divider

            overviewStat(
                value: "\(improvingCount)",
                label: "Improving",
                icon: "arrow.up.right"
            )
        }
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private func overviewStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.teal)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppColors.separator)
            .frame(width: 1, height: 36)
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

#Preview {
    NavigationStack {
        SkillListView()
    }
}
