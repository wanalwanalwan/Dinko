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
            Form {
                skillInfoSection(viewModel)

                if viewModel.showInitialRating {
                    initialRatingSection(viewModel)
                }

                if viewModel.showInlineSubskills {
                    inlineSubskillsSection(viewModel)
                }

                if viewModel.showExistingSubskills {
                    existingSubskillsSection(viewModel)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(AppColors.coral)
                            .font(AppTypography.caption)
                    }
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
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

    // MARK: - Skill Info

    private func skillInfoSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section("Skill Info") {
            TextField("Skill name", text: Binding(
                get: { viewModel.name },
                set: { viewModel.name = $0 }
            ))

            Picker("Category", selection: Binding(
                get: { viewModel.category },
                set: { viewModel.category = $0 }
            )) {
                ForEach(SkillCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }

            TextField("Description (optional)", text: Binding(
                get: { viewModel.skillDescription },
                set: { viewModel.skillDescription = $0 }
            ), axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Initial Rating

    private func initialRatingSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack {
                    Text("Rating")
                    Spacer()
                    Text("\(Int(viewModel.initialRating))%")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.teal)
                }

                Slider(
                    value: Binding(
                        get: { viewModel.initialRating },
                        set: { viewModel.initialRating = $0 }
                    ),
                    in: 0...100,
                    step: 1
                )
                .tint(AppColors.teal)

                Text("Leave at 0 to skip initial rating")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        } header: {
            Text("Initial Rating")
        }
    }

    // MARK: - Inline Subskills (Create Mode)

    private func inlineSubskillsSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section {
            if viewModel.pendingSubskills.isEmpty {
                Text("Add subskills to break this skill into smaller parts.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(Binding(
                get: { viewModel.pendingSubskills },
                set: { viewModel.pendingSubskills = $0 }
            )) { $subskill in
                VStack(spacing: AppSpacing.xxs) {
                    HStack {
                        Text(viewModel.iconName)
                            .font(.body)
                            .frame(width: 24)

                        Text(subskill.name)
                            .font(AppTypography.body)

                        Spacer()

                        Text("\(Int(subskill.rating))%")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.teal)
                            .frame(width: 40, alignment: .trailing)
                    }

                    Slider(value: $subskill.rating, in: 0...100, step: 1)
                        .tint(AppColors.teal)
                }
            }
            .onDelete { indexSet in
                let subskills = viewModel.pendingSubskills
                for index in indexSet {
                    viewModel.removePendingSubskill(subskills[index])
                }
            }

            HStack {
                TextField("Subskill name", text: Binding(
                    get: { viewModel.newSubskillName },
                    set: { viewModel.newSubskillName = $0 }
                ))

                Button {
                    viewModel.addPendingSubskill()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AppColors.teal)
                }
                .disabled(viewModel.newSubskillName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Subskills")
        }
    }

    // MARK: - Existing Subskills (Edit Mode)

    private func existingSubskillsSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section {
            if viewModel.subskills.isEmpty {
                Text("No subskills yet. Add subskills to break this skill into smaller parts.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(viewModel.subskills) { subskill in
                HStack {
                    Text(subskill.iconName)
                        .font(.body)
                        .frame(width: 24)

                    Text(subskill.name)
                        .font(AppTypography.body)
                }
            }

            Button {
                showingAddSubskill = true
            } label: {
                Label("Add Subskill", systemImage: "plus.circle.fill")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.teal)
            }
        } header: {
            Text("Subskills")
        }
    }
}

#Preview {
    AddEditSkillView()
}
