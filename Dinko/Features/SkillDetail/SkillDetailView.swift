import SwiftUI
import Charts

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingRateSkill = false
    @State private var showingAddSubskill = false
    @State private var showingArchiveConfirm = false
    @State private var showingDeleteConfirm = false
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

                if viewModel.isParentSkill {
                    subskillsSection(viewModel)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xxs)

            Spacer().frame(height: AppSpacing.xl)

            actionButtons(viewModel)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.lg)
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
        .alert("Archive Skill", isPresented: $showingArchiveConfirm) {
            Button("Archive", role: .destructive) {
                Task {
                    await viewModel.archiveSkill()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if viewModel.hasSubskills {
                Text("This will archive \"\(skill.name)\" and all its subskills. You can restore them later.")
            } else {
                Text("This will archive \"\(skill.name)\". You can restore it later.")
            }
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
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        let tier = SkillTier(rating: viewModel.latestRating)
        return VStack(spacing: AppSpacing.xs) {
            Text(skill.iconName)
                .font(.system(size: 56))

            Text("\(viewModel.latestRating)%")
                .font(AppTypography.ratingLarge)
                .foregroundStyle(AppColors.teal)

            Text(tier.displayName)
                .font(AppTypography.callout)
                .fontWeight(.semibold)
                .foregroundStyle(tier.color)

            if viewModel.hasSubskills {
                Text("average of \(viewModel.subskills.count) subskills")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
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
                let rating = viewModel.subskillRatings[subskill.id] ?? 0
                let subTier = SkillTier(rating: rating)
                let delta = viewModel.subskillDeltas[subskill.id]
                NavigationLink(value: subskill) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack {
                            Text(subskill.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            if let delta, delta != 0 {
                                Text(delta > 0 ? "+\(delta)%" : "\(delta)%")
                                    .font(AppTypography.trendValue)
                                    .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
                            }

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        ProgressBar(progress: Double(rating) / 100.0)

                        Text(subTier.displayName)
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(subTier.color)
                    }
                    .padding(AppSpacing.xs)
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                }
                .buttonStyle(.plain)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Action Buttons

    private func actionButtons(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: AppSpacing.xs) {
            if viewModel.isParentSkill {
                Button {
                    showingArchiveConfirm = true
                } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "archivebox")
                        Text("Archive Skill")
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.coral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                }
            }

            Button {
                showingDeleteConfirm = true
            } label: {
                HStack(spacing: AppSpacing.xxs) {
                    Image(systemName: "trash")
                    Text("Delete Skill")
                }
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.coral.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkillDetailView(skill: PreviewData.sampleServe)
    }
}
