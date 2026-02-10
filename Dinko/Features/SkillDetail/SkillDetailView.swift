import SwiftUI

struct SkillDetailView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: SkillDetailViewModel?
    @State private var showingRateSkill = false
    @State private var showingAddSubskill = false
    @State private var showingArchiveConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var ratingNotesExpanded = false
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    ratingHero(viewModel)

                    notesSection(viewModel)

                    if viewModel.isParentSkill {
                        subskillsSection(viewModel)
                    }

                    ratingNotesSection(viewModel)

                    Spacer(minLength: 0)

                    actionButtons(viewModel)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.lg)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .frame(minHeight: geometry.size.height)
            }
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
    }

    // MARK: - Rating Hero

    private func ratingHero(_ viewModel: SkillDetailViewModel) -> some View {
        let tier = SkillTier(rating: viewModel.latestRating)
        return VStack(spacing: AppSpacing.xs) {
            RatingBadge(rating: viewModel.latestRating, size: 160, ringColor: tier.color)
                .padding(.bottom, AppSpacing.xxs)

            Text(skill.name)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text(tier.displayName.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tier.color)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxxs)
                .background(tier.color.opacity(0.15))
                .clipShape(Capsule())

            HStack(spacing: AppSpacing.xxxs) {
                Text(viewModel.lastUpdatedText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let delta = viewModel.weeklyDelta, delta != 0 {
                    Text("·")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)

                    Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(delta > 0 ? AppColors.teal : AppColors.coral)

                    Text(delta > 0 ? "+\(delta)% this week" : "\(delta)% this week")
                        .font(AppTypography.caption)
                        .foregroundStyle(delta > 0 ? AppColors.teal : AppColors.coral)
                }
            }

            if !viewModel.hasSubskills && skill.status == .active {
                Button {
                    showingRateSkill = true
                } label: {
                    Text("Update Mastery")
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
    }

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("SUBSKILLS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                if skill.status == .active {
                    Button {
                        showingAddSubskill = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppColors.teal)
                    }
                    .accessibilityLabel("Add Subskill")
                }
            }
            .padding(.bottom, AppSpacing.xs)

            if viewModel.subskills.isEmpty {
                Text("Break this skill into subskills to track progress in more detail.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.xxs)
            }

            ForEach(Array(viewModel.subskills.enumerated()), id: \.element.id) { index, subskill in
                let rating = viewModel.subskillRatings[subskill.id] ?? 0

                if index > 0 {
                    Divider()
                }

                NavigationLink(value: subskill) {
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                            Text(subskill.name)
                                .font(AppTypography.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            ProgressBar(progress: Double(rating) / 100.0)
                        }

                        Text("\(rating)%")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.sm)
    }

    // MARK: - Notes Section

    private func notesSection(_ viewModel: SkillDetailViewModel) -> some View {
        NavigationLink {
            SkillNotesView(
                skillName: skill.name,
                notes: viewModel.skill.description
            ) { updatedNotes in
                await viewModel.updateNotes(updatedNotes)
            }
        } label: {
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(AppColors.teal)

                Text("Notes")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if !viewModel.skill.description.isEmpty {
                    Text(viewModel.skill.description)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 140, alignment: .trailing)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Rating Notes Section

    @ViewBuilder
    private func ratingNotesSection(_ viewModel: SkillDetailViewModel) -> some View {
        let ratingsWithNotes = viewModel.ratings
            .filter { $0.notes != nil && !$0.notes!.isEmpty }
            .sorted { $0.date > $1.date }

        if !ratingsWithNotes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        ratingNotesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(AppColors.teal)

                        Text("Rating Notes")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Text("\(ratingsWithNotes.count)")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: ratingNotesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if ratingNotesExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(ratingsWithNotes) { rating in
                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                HStack {
                                    Text("\(rating.rating)%")
                                        .font(AppTypography.callout)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(AppColors.teal)

                                    Spacer()

                                    Text(rating.date, style: .date)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Text(rating.notes!)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            .padding(AppSpacing.xs)
                            .background(AppColors.background)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Action Buttons

    private func actionButtons(_ viewModel: SkillDetailViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()

            if viewModel.isParentSkill {
                Button {
                    showingArchiveConfirm = true
                } label: {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "archivebox")
                        Text("Archive Skill")
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                }

                Divider()
            }

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
        }
    }
}

#Preview {
    NavigationStack {
        SkillDetailView(skill: PreviewData.sampleServe)
    }
}
