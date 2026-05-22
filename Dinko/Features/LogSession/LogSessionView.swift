import SwiftUI

struct LogSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Bindable var viewModel: LogSessionViewModel
    var selectedTab: Binding<Int>?

    private let durations = [30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    sessionTypeHeader
                    durationPicker
                    skillsSection
                    notesSection

                    if viewModel.sessionType == .drill {
                        generateDrillsButton
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.coral)
                            .padding(.horizontal, AppSpacing.sm)
                    }

                    saveButton
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .task {
                await viewModel.loadSkills()
            }
            .onChange(of: viewModel.saveSucceeded) { _, succeeded in
                if succeeded {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Session Type Header

    private var sessionTypeHeader: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: viewModel.sessionType.iconName)
                .font(.system(size: 20, weight: .semibold))
            Text(viewModel.sessionType.displayName)
                .font(AppTypography.headline)
        }
        .foregroundStyle(AppColors.teal)
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.primaryTint)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Duration")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xxs) {
                    ForEach(durations, id: \.self) { minutes in
                        let isSelected = viewModel.duration == minutes
                        Button {
                            viewModel.duration = minutes
                        } label: {
                            Text("\(minutes) min")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xxs)
                                .background(isSelected ? AppColors.teal : AppColors.cardBackground)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text("Skills Worked On")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(viewModel.selectedSkillIds.count) selected")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            if viewModel.skills.isEmpty {
                Text("No skills found. Add skills in the Progress tab.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.md)
            } else {
                VStack(spacing: AppSpacing.xxs) {
                    ForEach(viewModel.skillsByCategory, id: \.category) { group in
                        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                            Text(group.category.displayName)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.top, AppSpacing.xxxs)

                            ForEach(group.skills) { skill in
                                SkillSelectionRow(
                                    skill: skill,
                                    isSelected: viewModel.selectedSkillIds.contains(skill.id)
                                ) {
                                    viewModel.toggleSkill(skill.id)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.xs)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            }
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Notes")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            TextField("How did it go?", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .font(AppTypography.body)
                .padding(AppSpacing.xs)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Generate Drills Button

    private var generateDrillsButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedTab?.wrappedValue = 1
            }
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "sparkles")
                Text("Generate Drills with Coach")
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(AppColors.teal)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.primaryTint)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task {
                await viewModel.save()
            }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Log Session")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(viewModel.canSave ? AppColors.teal : AppColors.lockedGray)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canSave)
    }
}

// MARK: - Skill Selection Row

private struct SkillSelectionRow: View {
    let skill: Skill
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? AppColors.teal : AppColors.lockedGray)

                Text(skill.category.iconName)
                    .font(.system(size: 16))

                Text(skill.name)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()
            }
            .padding(.vertical, AppSpacing.xxxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let deps = DependencyContainer()
    let vm = LogSessionViewModel(
        skillRepository: deps.skillRepository,
        sessionRepository: deps.sessionRepository,
        journalEntryRepository: deps.journalEntryRepository
    )
    LogSessionView(viewModel: vm)
}
