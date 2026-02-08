import SwiftUI

struct AddEditSkillView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddEditSkillViewModel?
    @State private var showingAddSubskill = false
    let skill: Skill?
    let parentSkillId: UUID?

    init(skill: Skill? = nil, parentSkillId: UUID? = nil) {
        self.skill = skill
        self.parentSkillId = parentSkillId
    }

    var body: some View {
        Group {
            if let viewModel {
                formContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = AddEditSkillViewModel(
                    skill: skill,
                    parentSkillId: parentSkillId,
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository
                )
                viewModel = vm
                await vm.loadSubskills()
            }
        }
    }

    private func formContent(_ viewModel: AddEditSkillViewModel) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    skillInfoCard(viewModel)

                    if viewModel.showInitialRating {
                        startingLevelCard(viewModel)
                    }

                    if viewModel.showInlineSubskills {
                        breakItDownSection(viewModel)
                    }

                    if viewModel.showExistingSubskills {
                        existingSubskillsSection(viewModel)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(AppColors.coral)
                            .font(AppTypography.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.cardBackground)
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Save")
                            .font(AppTypography.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(viewModel.isValid ? AppColors.teal : AppColors.lockedGray)
                            .clipShape(Capsule())
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showingAddSubskill, onDismiss: {
                Task { await viewModel.loadSubskills() }
            }) {
                if let skillId = viewModel.skillId {
                    AddEditSkillView(parentSkillId: skillId)
                }
            }
        }
    }

    // MARK: - Skill Info Card

    private func skillInfoCard(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Skill Name
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Skill Name")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.teal)

                TextField("e.g., Backhand Dink Control", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ))
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)
            }

            Divider()

            // Category
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Category")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.teal)

                Menu {
                    Picker("", selection: Binding(
                        get: { viewModel.category },
                        set: { viewModel.category = $0 }
                    )) {
                        ForEach(SkillCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.category.displayName)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.xs)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xxs))
                }
            }

            Divider()

            // Notes
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(spacing: AppSpacing.xxxs) {
                    Text("Notes")
                        .font(AppTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.teal)

                    Text("(optional)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                TextField("What do you want to improve?", text: Binding(
                    get: { viewModel.skillDescription },
                    set: { viewModel.skillDescription = $0 }
                ), axis: .vertical)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(3...6)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Starting Level Card

    private func startingLevelCard(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Starting Level")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text("Give yourself an honest baseline")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            Text("\(Int(viewModel.initialRating))%")
                .font(AppTypography.ratingLarge)
                .foregroundStyle(AppColors.teal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxs)

            Slider(
                value: Binding(
                    get: { viewModel.initialRating },
                    set: { viewModel.initialRating = $0 }
                ),
                in: 0...100,
                step: 1
            )
            .tint(AppColors.teal)

            Text("You can skip this and rate later")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Break It Down (Inline Subskills)

    private func breakItDownSection(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxxs) {
                Text("Break it down")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("(optional)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text("Add specific areas to track within this skill")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            // Add subskill input
            HStack(spacing: AppSpacing.xxs) {
                TextField("e.g., Contact point height", text: Binding(
                    get: { viewModel.newSubskillName },
                    set: { viewModel.newSubskillName = $0 }
                ))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .onSubmit {
                    viewModel.addPendingSubskill()
                }

                Button {
                    viewModel.addPendingSubskill()
                } label: {
                    Image(systemName: "plus")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .disabled(viewModel.newSubskillName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppSpacing.xs)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))

            // Pending subskill chips
            ForEach(viewModel.pendingSubskills) { subskill in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.teal)
                        .frame(width: 4)

                    Text(subskill.name)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.leading, AppSpacing.xs)

                    Spacer()

                    Button {
                        viewModel.removePendingSubskill(subskill)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(AppSpacing.xxs)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xxs)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
            }
        }
    }

    // MARK: - Existing Subskills (Edit Mode)

    private func existingSubskillsSection(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxxs) {
                Text("Subskills")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Text("(\(viewModel.subskills.count))")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if viewModel.subskills.isEmpty {
                Text("No subskills yet. Add subskills to break this skill into smaller parts.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(viewModel.subskills) { subskill in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.teal)
                        .frame(width: 4)

                    Text(subskill.name)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.leading, AppSpacing.xs)

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xxs)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
            }

            Button {
                showingAddSubskill = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Subskill")
                }
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.teal)
            }
            .padding(.top, AppSpacing.xxxs)
        }
    }
}

#Preview {
    AddEditSkillView()
}
