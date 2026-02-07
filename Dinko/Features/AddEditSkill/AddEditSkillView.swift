import SwiftUI

struct AddEditSkillView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: AddEditSkillViewModel?
    let skill: Skill?

    init(skill: Skill? = nil) {
        self.skill = skill
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
                    skillRepository: dependencies.skillRepository,
                    progressCheckerRepository: dependencies.progressCheckerRepository
                )
                viewModel = vm
                await vm.loadExistingCheckers()
            }
        }
    }

    private func formContent(_ viewModel: AddEditSkillViewModel) -> some View {
        NavigationStack {
            Form {
                skillInfoSection(viewModel)
                iconSection(viewModel)
                checkersSection(viewModel)

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

    // MARK: - Checkers

    private func checkersSection(_ viewModel: AddEditSkillViewModel) -> some View {
        Section("Progress Checkers") {
            ForEach(viewModel.checkerNames.indices, id: \.self) { index in
                HStack {
                    TextField("Checker \(index + 1)", text: Binding(
                        get: { viewModel.checkerNames[index] },
                        set: { viewModel.checkerNames[index] = $0 }
                    ))

                    if viewModel.checkerNames.count > 1 {
                        Button {
                            viewModel.removeChecker(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppColors.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                viewModel.addChecker()
            } label: {
                Label("Add Checker", systemImage: "plus.circle.fill")
                    .foregroundStyle(AppColors.teal)
            }
        }
    }
}

#Preview {
    AddEditSkillView()
}
