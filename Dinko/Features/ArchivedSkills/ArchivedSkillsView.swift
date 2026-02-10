import SwiftUI

struct ArchivedSkillsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ArchivedSkillsViewModel?

    var body: some View {
        Group {
            if let viewModel {
                archivedContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Archived")
        .navigationDestination(for: Skill.self) { skill in
            SkillDetailView(skill: skill)
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
                let vm = ArchivedSkillsViewModel(
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
    private func archivedContent(_ viewModel: ArchivedSkillsViewModel) -> some View {
        if viewModel.skills.isEmpty {
            emptyState
        } else {
            ScrollView {
                Text("Skills you've mastered")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.top, AppSpacing.xxs)

                LazyVStack(spacing: AppSpacing.xs) {
                    ForEach(viewModel.skills) { skill in
                        let rating = viewModel.latestRatings[skill.id] ?? 0
                        NavigationLink(value: skill) {
                            ArchivedSkillCard(skill: skill, rating: rating)
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
            "No Archived Skills",
            systemImage: "archivebox",
            description: Text("Skills you archive will appear here.")
        )
    }
}

// MARK: - Archived Skill Card

private struct ArchivedSkillCard: View {
    let skill: Skill
    let rating: Int

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private var tier: SkillTier { SkillTier(rating: rating) }
    private var isWeapon: Bool { tier == .weapon }

    private var completedDateText: String {
        guard let date = skill.archivedDate else { return "" }
        return Self.dateFormatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Text(skill.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                RatingBadge(
                    rating: rating,
                    size: 44,
                    ringColor: isWeapon ? AppColors.successGreen : tier.color,
                    showCheckmark: isWeapon
                )
            }

            Text(tier.displayName.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .padding(.horizontal, AppSpacing.xxs)
                .padding(.vertical, AppSpacing.xxxs)
                .background(tier.color.opacity(0.15))
                .clipShape(Capsule())

            HStack(spacing: AppSpacing.xxxs) {
                Text("Archived")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Text(completedDateText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.top, AppSpacing.xxxs)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}

#Preview {
    NavigationStack {
        ArchivedSkillsView()
    }
}
