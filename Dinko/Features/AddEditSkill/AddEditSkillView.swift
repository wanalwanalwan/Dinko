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
                    skillRepository: dependencies.skillRepository
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

                if viewModel.isTopLevelSkill {
                    subskillsSection(viewModel)
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

    // MARK: - Subskills

    private func subskillsSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section {
            if viewModel.subskills.isEmpty {
                Text("No subskills yet. Add subskills to break this skill into smaller parts.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(viewModel.subskills) { subskill in
                HStack {
                    Image(systemName: subskill.iconName)
                        .font(.body)
                        .foregroundStyle(AppColors.teal)
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
