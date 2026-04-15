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
                if viewModel.isEditing {
                    editFormContent(viewModel)
                } else {
                    createFormContent(viewModel)
                }
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

    // MARK: - Create Flow (Compact Bottom Sheet)

    private func createFormContent(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xs)

            // Header
            HStack {
                Text(viewModel.navigationTitle)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("Cancel") { dismiss() }
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    // Skill name
                    createNameField(viewModel)

                    // Category pills
                    createCategoryPills(viewModel)

                    // Advanced options (collapsed)
                    createAdvancedSection(viewModel)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(AppColors.coral)
                            .font(AppTypography.caption)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            // Pinned create button
            createButton(viewModel)
        }
        .background(AppColors.cardBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Create: Name Field

    private func createNameField(_ viewModel: AddEditSkillViewModel) -> some View {
        TextField("e.g., Backhand Dink Control", text: Binding(
            get: { viewModel.name },
            set: { viewModel.name = $0 }
        ))
        .font(AppTypography.headline)
        .foregroundStyle(AppColors.textPrimary)
        .padding(AppSpacing.xs)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
    }

    // MARK: - Create: Category Pills

    private func createCategoryPills(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Category")
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)

            FlowLayout(spacing: AppSpacing.xxs) {
                ForEach(SkillCategory.allCases) { category in
                    let isSelected = viewModel.category == category
                    Button {
                        viewModel.category = category
                    } label: {
                        HStack(spacing: AppSpacing.xxxs) {
                            Text(category.iconName)
                                .font(.system(size: 13))
                            Text(category.displayName)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? AppColors.teal.opacity(0.12) : AppColors.background)
                        .foregroundStyle(isSelected ? AppColors.teal : AppColors.textSecondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? AppColors.teal.opacity(0.4) : AppColors.separator,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
    }

    // MARK: - Create: Additional Options

    private func createAdvancedSection(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if viewModel.showInitialRating {
                createStartingLevel(viewModel)
            }

            createNotes(viewModel)

            if viewModel.showInlineSubskills {
                createSubskills(viewModel)
            }
        }
    }

    // MARK: - Create: Starting Level (Compact)

    private func createStartingLevel(_ viewModel: AddEditSkillViewModel) -> some View {
        let isAutoCalculated = viewModel.hasSubskillRatings
        let displayRating = isAutoCalculated ? viewModel.averageSubskillRating : Int(viewModel.initialRating)

        return VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            HStack {
                Text("Starting Level")
                    .font(AppTypography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(displayRating)%")
                    .font(AppTypography.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.teal)
            }

            if isAutoCalculated {
                Text("Avg of subskills")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Slider(
                    value: Binding(
                        get: { viewModel.initialRating },
                        set: { viewModel.initialRating = $0 }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(AppColors.teal)
            }
        }
        .padding(AppSpacing.xs)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
    }

    // MARK: - Create: Notes

    private func createNotes(_ viewModel: AddEditSkillViewModel) -> some View {
        TextField("Notes (optional)", text: Binding(
            get: { viewModel.skillDescription },
            set: { viewModel.skillDescription = $0 }
        ), axis: .vertical)
        .font(AppTypography.body)
        .foregroundStyle(AppColors.textPrimary)
        .lineLimit(2...4)
        .padding(AppSpacing.xs)
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
    }

    // MARK: - Create: Subskills

    private func createSubskills(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Break it down")
                .font(AppTypography.callout)
                .fontWeight(.medium)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: AppSpacing.xxs) {
                TextField("Add a subskill...", text: Binding(
                    get: { viewModel.newSubskillName },
                    set: { viewModel.newSubskillName = $0 }
                ))
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .onSubmit { viewModel.addPendingSubskill() }

                Button {
                    viewModel.addPendingSubskill()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.teal)
                }
                .disabled(viewModel.newSubskillName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppSpacing.xs)
            .background(AppColors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))

            ForEach(Binding(
                get: { viewModel.pendingSubskills },
                set: { viewModel.pendingSubskills = $0 }
            )) { $subskill in
                VStack(spacing: AppSpacing.xxxs) {
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.teal)
                            .frame(width: 3)

                        Text(subskill.name)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.leading, AppSpacing.xxs)

                        Spacer()

                        Text("\(Int(subskill.rating))%")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 32, alignment: .trailing)

                        Button { viewModel.removePendingSubskill(subskill) } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(AppSpacing.xxxs)
                        }
                    }

                    Slider(value: $subskill.rating, in: 0...100, step: 1)
                        .tint(AppColors.teal)
                        .padding(.leading, AppSpacing.xxs)
                }
                .padding(.vertical, AppSpacing.xxs)
                .padding(.horizontal, AppSpacing.xxs)
                .background(AppColors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
            }
        }
    }

    // MARK: - Create: Action Button

    private func createButton(_ viewModel: AddEditSkillViewModel) -> some View {
        let buttonLabel = parentSkillId != nil ? "Create Subskill" : "Create Skill"

        return Button {
            Task {
                if await viewModel.save() {
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(buttonLabel)
                }
            }
            .font(AppTypography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .background(viewModel.isValid ? AppColors.teal : AppColors.lockedGray)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
        }
        .disabled(!viewModel.isValid || viewModel.isSaving)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .padding(.top, AppSpacing.xxs)
    }

    // MARK: - Edit Flow (Existing Full Form)

    private func editFormContent(_ viewModel: AddEditSkillViewModel) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    skillInfoCard(viewModel)

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
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    // MARK: - Edit: Skill Info Card

    private func skillInfoCard(_ viewModel: AddEditSkillViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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

    // MARK: - Edit: Existing Subskills

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
