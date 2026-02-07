import SwiftUI
import Charts

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    let skill: Skill

    var body: some View {
        Group {
            if let viewModel {
                detailContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(skill.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = SkillDetailViewModel(
                    skill: skill,
                    skillRepository: dependencies.skillRepository,
                    progressCheckerRepository: dependencies.progressCheckerRepository,
                    skillRatingRepository: dependencies.skillRatingRepository
                )
                viewModel = vm
                await vm.loadDetail()
            }
        }
    }

    private func detailContent(_ viewModel: SkillDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                ratingHero(viewModel)
                ratingHistoryChart(viewModel)
                checkersSection(viewModel)
                archiveButton(viewModel)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)
        }
        .refreshable {
            await viewModel.loadDetail()
        }
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text(skill.iconName)
                .font(.system(size: 56))

            Text("\(viewModel.latestRating)%")
                .font(AppTypography.ratingLarge)
                .foregroundStyle(AppColors.teal)

            Text("out of 100%")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Rating History Chart

    @ViewBuilder
    private func ratingHistoryChart(_ viewModel: SkillDetailViewModel) -> some View {
        if viewModel.ratings.count >= 2 {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Rating History")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Chart {
                    ForEach(viewModel.ratings) { rating in
                        LineMark(
                            x: .value("Date", rating.date),
                            y: .value("Rating", rating.rating)
                        )
                        .foregroundStyle(AppColors.coral)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", rating.date),
                            y: .value("Rating", rating.rating)
                        )
                        .foregroundStyle(AppColors.coral)
                        .symbolSize(30)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Checkers

    private func checkersSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Progress Checkers")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            if viewModel.checkers.isEmpty {
                Text("No checkers yet.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.xxs)
            } else {
                ForEach(viewModel.checkers) { checker in
                    CheckerItem(
                        name: checker.name,
                        isCompleted: checker.isCompleted
                    ) {
                        Task { await viewModel.toggleChecker(checker) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Archive

    private func archiveButton(_ viewModel: SkillDetailViewModel) -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.archiveSkill()
                dismiss()
            }
        } label: {
            Text("Archive Skill")
                .font(AppTypography.body)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppColors.coral)
        .padding(.top, AppSpacing.xs)
    }
}

#Preview {
    NavigationStack {
        SkillDetailView(skill: PreviewData.sampleServe)
    }
}
