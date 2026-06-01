import SwiftUI

struct AddEditSkillView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddEditSkillViewModel?
    @State private var showingAddSubskill = false
    let skill: Skill?
    let parentSkillId: UUID?
    var onDismiss: (() -> Void)?

    init(skill: Skill? = nil, parentSkillId: UUID? = nil, onDismiss: (() -> Void)? = nil) {
        self.skill = skill
        self.parentSkillId = parentSkillId
        self.onDismiss = onDismiss
    }

    private func performDismiss() {
        if let onDismiss { onDismiss() } else { dismiss() }
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
                .fill(AppColors.separator)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {

                    // Header row
                    HStack(alignment: .firstTextBaseline) {
                        Text(viewModel.navigationTitle)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        Button("Cancel") { performDismiss() }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.top, AppSpacing.xs)

                    // Name field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SKILL NAME")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textSecondary)
                        createNameField(viewModel)
                    }

                    // Rating
                    createStartingLevel(viewModel)

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textSecondary)
                        createNotes(viewModel)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(AppColors.coral)
                            .font(AppTypography.caption)
                    }

                    createButton(viewModel)
                        .padding(.top, AppSpacing.xxs)
                        .padding(.bottom, AppSpacing.lg)
                }
                .padding(.horizontal, AppSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        .background(AppColors.cardBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden) // we draw our own
        .presentationCornerRadius(24)
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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .stroke(AppColors.separator.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Create: Starting Level (Premium slider)

    private func createStartingLevel(_ viewModel: AddEditSkillViewModel) -> some View {
        let isAutoCalculated = viewModel.hasSubskillRatings
        let displayRating = isAutoCalculated
            ? viewModel.averageSubskillRating
            : Int(viewModel.initialRating.rounded())

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Where are you today?")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("You can update this anytime.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text("\(displayRating)%")
                    .font(Font.custom("Sora-Bold", size: 22))
                    .foregroundStyle(AppColors.primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7),
                               value: displayRating)
            }

            if isAutoCalculated {
                Label("Calculated from subskills", systemImage: "function")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                PremiumRatingSlider(
                    value: Binding(
                        get: { viewModel.initialRating },
                        set: { viewModel.initialRating = $0 }
                    )
                )
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .stroke(AppColors.separator.opacity(0.5), lineWidth: 1))
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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .stroke(AppColors.separator.opacity(0.5), lineWidth: 1))
    }

    // MARK: - Create: Action Button

    private func createButton(_ viewModel: AddEditSkillViewModel) -> some View {
        let buttonLabel = parentSkillId != nil ? "Create Subskill" : "Create Skill"

        return Button {
            Task {
                if await viewModel.save() {
                    performDismiss()
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
            .background(viewModel.isValid ? AppColors.primary : AppColors.lockedGray)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .disabled(!viewModel.isValid || viewModel.isSaving)
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
                            .background(viewModel.isValid ? AppColors.primary : AppColors.lockedGray)
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
                    .foregroundStyle(AppColors.primary)

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
                    .foregroundStyle(AppColors.primary)

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
                        .foregroundStyle(AppColors.primary)

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
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius)
            .stroke(AppColors.separator.opacity(0.5), lineWidth: 1))
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
                        .fill(AppColors.primary)
                        .frame(width: 4)

                    Text(subskill.name)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.leading, AppSpacing.xs)

                    Spacer()
                }
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.xxs)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadiusSmall))
            }

            Button {
                showingAddSubskill = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Subskill")
                }
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.primary)
            }
            .padding(.top, AppSpacing.xxxs)
        }
    }
}

#Preview {
    AddEditSkillView()
}
