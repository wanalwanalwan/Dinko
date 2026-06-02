import SwiftUI

struct FocusSkillPickerSheet: View {
    let existingSkills: [(skill: Skill, rating: Int)]
    let onSave: ([FocusSkillEntry]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedSkills: [Skill] = []
    @State private var showNewSkillField = false
    @State private var newSkillName = ""

    // Skills the user created inline during this session (before CoreData)
    @State private var inlineCustomSkills: [Skill] = []

    private var allSkills: [(skill: Skill, rating: Int)] {
        let customs = inlineCustomSkills.map { (skill: $0, rating: 0) }
        return existingSkills + customs
    }

    var body: some View {
        NavigationStack {
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
                    // Existing + inline-created skills
                    Section {
                        if allSkills.isEmpty && !showNewSkillField {
                            Text("No skills yet — create one below.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                                .listRowBackground(AppColors.cardBackground)
                        }

                        ForEach(allSkills, id: \.skill.id) { item in
                            skillRow(item.skill, rating: item.rating)
                        }
                    } header: {
                        Text("Your Skills")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    // Add new skill section
                    Section {
                        if showNewSkillField {
                            HStack(spacing: AppSpacing.xs) {
                                TextField("Skill name...", text: $newSkillName)
                                    .font(.system(size: 15, design: .rounded))
                                    .autocorrectionDisabled()
                                    .onSubmit { addCustomSkill() }

                                Button("Add") { addCustomSkill() }
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(newSkillName.trimmingCharacters(in: .whitespaces).isEmpty
                                                     ? AppColors.textSecondary : AppColors.primary)
                                    .disabled(newSkillName.trimmingCharacters(in: .whitespaces).isEmpty)

                                Button {
                                    withAnimation { showNewSkillField = false; newSkillName = "" }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12))
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .listRowBackground(AppColors.cardBackground)
                        } else {
                            Button {
                                withAnimation { showNewSkillField = true }
                            } label: {
                                Label("Create a new skill", systemImage: "plus.circle")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(AppColors.primary)
                            }
                            .listRowBackground(AppColors.cardBackground)
                        }
                    } header: {
                        Text("Custom")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
            .background(AppColors.background)
            .navigationTitle("Focus Skills")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedSkills.isEmpty ? AppColors.textSecondary : AppColors.primary)
                        .disabled(selectedSkills.isEmpty)
                }
            }
            .toolbarBackground(AppColors.background, for: .navigationBar)
        }
        .presentationBackground(AppColors.background)
    }

    // MARK: - Row

    private func skillRow(_ skill: Skill, rating: Int) -> some View {
        let selectedIndex = selectedSkills.firstIndex(where: { $0.id == skill.id })
        let isSelected = selectedIndex != nil

        return Button {
            toggle(skill)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Priority badge or empty circle
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
                    if rating > 0 {
                        Text("\(rating)%")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
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

    private func toggle(_ skill: Skill) {
        if let idx = selectedSkills.firstIndex(where: { $0.id == skill.id }) {
            selectedSkills.remove(at: idx)
        } else {
            guard selectedSkills.count < 3 else { return }
            selectedSkills.append(skill)
        }
    }

    private func addCustomSkill() {
        let trimmed = newSkillName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let skill = Skill(name: trimmed, iconName: "✨")
        inlineCustomSkills.append(skill)
        withAnimation { showNewSkillField = false; newSkillName = "" }
        // Auto-select it if slots remain
        if selectedSkills.count < 3 { selectedSkills.append(skill) }
    }

    private func save() {
        let entries = selectedSkills.enumerated().map { idx, skill in
            FocusSkillEntry(
                id: skill.id,
                name: skill.name,
                icon: skill.iconName,
                categoryRaw: skill.category.rawValue,
                priorityIndex: idx
            )
        }
        onSave(entries)
        dismiss()
    }
}
