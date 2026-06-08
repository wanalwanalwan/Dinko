import SwiftUI

struct ProgramGenerationFlowView: View {
    let viewModel: ProgramViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showSkillPicker = false
    @State private var skillsWithRatings: [(skill: Skill, rating: Int)] = []
    @State private var selectedSkills: [Skill] = []
    @State private var selectedRatings: [UUID: Int] = [:]

    private let maxSkills = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.md) {
                if showSkillPicker {
                    skillPickerStep
                } else {
                    modeSelectionStep
                }
            }
            .background(AppColors.backgroundGradient.ignoresSafeArea())
            .navigationTitle(showSkillPicker ? "Pick Skills" : "Training Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if showSkillPicker {
                        Button {
                            withAnimation { showSkillPicker = false }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Back")
                            }
                            .foregroundStyle(AppColors.primary)
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .toolbarBackground(AppColors.background, for: .navigationBar)
        }
        .presentationBackground(AppColors.background)
        .task {
            skillsWithRatings = await viewModel.fetchSkillsWithRatings()
            // Pre-populate rating lookup
            for item in skillsWithRatings {
                selectedRatings[item.skill.id] = item.rating
            }
        }
    }

    // MARK: - Step 1: Mode Selection

    private var modeSelectionStep: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                Text("How do you want to train?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.top, AppSpacing.lg)

                Text("Choose a balanced program or target specific skills.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.md)

                VStack(spacing: AppSpacing.sm) {
                    GenerationModeCard(
                        icon: "figure.run.circle",
                        title: "General Training",
                        description: "Balanced program based on your overall skill level"
                    ) {
                        dismiss()
                        Task { await viewModel.generateProgram() }
                    }

                    GenerationModeCard(
                        icon: "target",
                        title: "Custom Focus",
                        description: "Pick skills to prioritize and get a targeted plan"
                    ) {
                        withAnimation { showSkillPicker = true }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
            }
        }
    }

    // MARK: - Step 2: Skill Picker

    private var skillPickerStep: some View {
        VStack(spacing: 0) {
            // Selection summary chips
            if !selectedSkills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xxs) {
                        ForEach(Array(selectedSkills.enumerated()), id: \.element.id) { index, skill in
                            HStack(spacing: 5) {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 17, height: 17)
                                    .background(AppColors.primary)
                                    .clipShape(Circle())
                                Text(skill.iconName)
                                    .font(.system(size: 13))
                                Text(skill.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                }
                .background(AppColors.background)

                Divider()
            }

            List {
                if skillsWithRatings.isEmpty {
                    Section {
                        Text("No skills yet. Add skills first to create a custom program.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .listRowBackground(AppColors.cardBackground)
                    }
                } else {
                    Section {
                        ForEach(skillsWithRatings, id: \.skill.id) { item in
                            skillRow(item.skill, rating: item.rating)
                        }
                    } header: {
                        Text("Select up to \(maxSkills) skills")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)

            // Generate CTA
            VStack(spacing: 0) {
                Divider()
                Button {
                    let focusSkills = selectedSkills.enumerated().map { index, skill in
                        ProgramFocusSkill(
                            id: skill.id,
                            name: skill.name,
                            iconName: skill.iconName,
                            category: skill.category.rawValue,
                            currentRating: selectedRatings[skill.id] ?? 0,
                            priority: index + 1
                        )
                    }
                    dismiss()
                    Task { await viewModel.generateCustomProgram(focusSkills: focusSkills) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Generate Program")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedSkills.isEmpty ? AppColors.primary.opacity(0.4) : AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
                .buttonStyle(.pressable)
                .disabled(selectedSkills.isEmpty)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .background(AppColors.cardBackground)
        }
    }

    // MARK: - Skill Row

    private func skillRow(_ skill: Skill, rating: Int) -> some View {
        let selectedIndex = selectedSkills.firstIndex(where: { $0.id == skill.id })
        let isSelected = selectedIndex != nil

        return Button {
            toggleSkill(skill)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? AppColors.primary : AppColors.separator, lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(isSelected ? AppColors.primary : Color.clear)
                        )
                    if let idx = selectedIndex {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Text(skill.iconName)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 4) {
                        Text("\(rating)%")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                        Text("·")
                            .foregroundStyle(AppColors.textSecondary)
                        Text(developmentLabel(for: rating))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(developmentColor(for: rating))
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? AppColors.primary.opacity(0.06) : AppColors.cardBackground)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Actions

    private func toggleSkill(_ skill: Skill) {
        if let idx = selectedSkills.firstIndex(where: { $0.id == skill.id }) {
            selectedSkills.remove(at: idx)
        } else {
            guard selectedSkills.count < maxSkills else { return }
            selectedSkills.append(skill)
        }
    }

    // MARK: - Helpers

    private func developmentLabel(for rating: Int) -> String {
        if rating < 40 { return "Drill-heavy" }
        if rating <= 70 { return "Mixed" }
        return "Game-focused"
    }

    private func developmentColor(for rating: Int) -> Color {
        if rating < 40 { return AppColors.coral }
        if rating <= 70 { return .orange }
        return AppColors.primary
    }
}
