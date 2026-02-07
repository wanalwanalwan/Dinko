import SwiftUI

struct AddEditSkillView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddEditSkillViewModel?
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
                viewModel = AddEditSkillViewModel(
                    skill: skill,
                    parentSkillId: parentSkillId,
                    skillRepository: dependencies.skillRepository
                )
            }
        }
    }

    private func formContent(_ viewModel: AddEditSkillViewModel) -> some View {
        NavigationStack {
            Form {
                skillInfoSection(viewModel)
                iconSection(viewModel)

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

    // MARK: - Icon Picker

    private func iconSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section("Icon") {
            let icons = [
                "figure.pickleball", "figure.run", "brain.head.profile",
                "target", "shield.fill", "bolt.fill",
                "hand.raised.fill", "arrow.triangle.swap", "eye.fill"
            ]
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: AppSpacing.xs) {
                ForEach(icons, id: \.self) { icon in
                    Button {
                        viewModel.iconName = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(
                                viewModel.iconName == icon
                                    ? AppColors.teal.opacity(0.2)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(
                                viewModel.iconName == icon
                                    ? AppColors.teal
                                    : AppColors.textSecondary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    AddEditSkillView()
}
