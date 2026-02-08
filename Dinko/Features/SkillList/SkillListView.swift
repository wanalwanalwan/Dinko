import SwiftUI

struct SkillListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: SkillListViewModel?
    @State private var showingAddSkill = false

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
                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.skills) { skill in
                        NavigationLink(value: skill) {
                            SkillCard(
                                skill: skill,
                                subskillCount: viewModel.subskillCounts[skill.id] ?? 0,
                                rating: viewModel.latestRatings[skill.id] ?? 0,
                                delta: viewModel.ratingDeltas[skill.id]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
            }
            .refreshable {
                await viewModel.loadSkills()
            }
        }
    }

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
