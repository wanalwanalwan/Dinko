import SwiftUI
import Charts

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingRateSkill = false
    @State private var showingAddSubskill = false
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
                    skillRatingRepository: dependencies.skillRatingRepository
                )
                viewModel = vm
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
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                ratingHero(viewModel)

                if !viewModel.hasSubskills {
                    ratingHistoryChart(viewModel)
                }

                subskillsSection(viewModel)

                archiveButton(viewModel)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)
        }
        .refreshable {
            await viewModel.loadDetail()
        }
        .sheet(isPresented: $showingRateSkill) {
            RateSkillView(
                skillName: skill.name,
                currentRating: viewModel.latestRating
            ) { rating, notes in
                await viewModel.saveRating(rating, notes: notes)
            }
        }
        .sheet(isPresented: $showingAddSubskill, onDismiss: {
            Task { await viewModel.loadDetail() }
        }) {
            AddEditSkillView(parentSkillId: skill.id)
        }
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: skill.iconName)
                .font(.system(size: 56))
                .foregroundStyle(AppColors.teal)

            Text("\(viewModel.latestRating)%")
                .font(AppTypography.ratingLarge)
                .foregroundStyle(AppColors.teal)

            if viewModel.hasSubskills {
                Text("average of \(viewModel.subskills.count) subskills")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("out of 100%")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    showingRateSkill = true
                } label: {
                    Text("Rate Skill")
                        .font(AppTypography.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.xxs)
                        .background(AppColors.teal)
                        .clipShape(Capsule())
                }
                .padding(.top, AppSpacing.xxs)
            }
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

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("Subskills")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    showingAddSubskill = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.teal)
                }
            }

            if viewModel.subskills.isEmpty {
                Text("Break this skill into subskills to track progress in more detail.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.xxs)
            }

            ForEach(viewModel.subskills) { subskill in
                NavigationLink(value: subskill) {
                    HStack {
                        Image(systemName: subskill.iconName)
                            .font(.body)
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 24)

                        Text(subskill.name)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        let rating = viewModel.subskillRatings[subskill.id] ?? 0
                        Text("\(rating)%")
                            .font(AppTypography.ratingBadge)
                            .foregroundStyle(rating > 0 ? AppColors.teal : AppColors.textSecondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.xxs)
                }
                .buttonStyle(.plain)
            }

            Button {
                showingAddSubskill = true
            } label: {
                Label("Add Subskill", systemImage: "plus.circle.fill")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.teal)
            }
            .padding(.top, AppSpacing.xxxs)
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
