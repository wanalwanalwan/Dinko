import SwiftUI

struct LogSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @Bindable var viewModel: LogSessionViewModel
    var selectedTab: Binding<Int>?

    private let durations = [30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if viewModel.isQuickMode {
                        dateCard
                        durationCard
                        quickSkillRatingsCard
                    } else {
                        sessionTypeCard
                        dateCard
                        durationCard
                        skillsCard
                    }
                    notesCard

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.coral)
                    }

                    saveButton
                        .padding(.top, AppSpacing.xxs)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl + 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task { await viewModel.loadSkills() }
        .onChange(of: viewModel.saveSucceeded) { _, succeeded in
            if succeeded { dismiss() }
        }
    }

    // MARK: - Sheet Header

    private var sheetHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.separator)
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack {
                Text("Log Session")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
        }
    }

    // MARK: - Session Type Card

    private var sessionTypeCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: viewModel.sessionType.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.sessionType.displayName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Session type")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AppColors.highlight)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Date Card

    private var dateCard: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Date")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            DatePicker(
                "",
                selection: $viewModel.sessionDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .tint(AppColors.primary)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Duration Card

    private var durationCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("Duration")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("\(viewModel.duration) min")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider().padding(.horizontal, AppSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durations, id: \.self) { minutes in
                        let isSelected = viewModel.duration == minutes
                        Button { viewModel.duration = minutes } label: {
                            Text("\(minutes) min")
                                .font(.system(size: 14, weight: isSelected ? .semibold : .medium,
                                              design: .rounded))
                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected
                                        ? AnyView(ZStack {
                                            LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDark],
                                                           startPoint: .top, endPoint: .bottom)
                                            LinearGradient(colors: [.white.opacity(0.15), .clear],
                                                           startPoint: .top,
                                                           endPoint: .init(x: 0.5, y: 0.55))
                                        })
                                        : AnyView(AppColors.background)
                                )
                                .clipShape(Capsule())
                                .shadow(color: isSelected ? AppColors.primary.opacity(0.25) : .clear,
                                        radius: 0, y: 2)
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Skills Card

    private var skillsCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "figure.pickleball")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("Skills Worked On")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                if viewModel.selectedSkillIds.count > 0 {
                    Text("\(viewModel.selectedSkillIds.count) selected")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider().padding(.horizontal, AppSpacing.sm)

            if viewModel.skills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text("No skills yet.\nAdd skills in the Progress tab.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.skillsByCategory, id: \.category) { group in
                        // Category label
                        Text(group.category.displayName.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.top, AppSpacing.xs)
                            .padding(.bottom, 4)

                        ForEach(group.skills) { skill in
                            SkillSelectionRow(
                                skill: skill,
                                isSelected: viewModel.selectedSkillIds.contains(skill.id),
                                rating: Binding(
                                    get: { viewModel.skillRatings[skill.id] ?? 50 },
                                    set: { viewModel.skillRatings[skill.id] = $0 }
                                ),
                                drills: viewModel.skillDrills[skill.id] ?? [],
                                completedDrillIds: viewModel.completedDrillIds,
                                isDrillSession: viewModel.sessionType == .drill,
                                onToggle: { viewModel.toggleSkill(skill.id) },
                                onToggleDrill: { viewModel.toggleDrill($0) }
                            )
                        }
                    }
                }
                .padding(.bottom, AppSpacing.xs)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Quick Skill Ratings Card

    private var quickSkillRatingsCard: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "figure.pickleball")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Text("How did these feel?")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Spacer()
                Text("\(viewModel.selectedSkillIds.count) skills")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider().padding(.horizontal, AppSpacing.sm)

            if viewModel.skills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    Text("No skills yet.\nAdd skills in the Progress tab.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
            } else {
                VStack(spacing: 0) {
                    let selectedSkills = viewModel.skills.filter { viewModel.selectedSkillIds.contains($0.id) }
                    ForEach(selectedSkills) { skill in
                        VStack(spacing: AppSpacing.xxs) {
                            HStack(spacing: AppSpacing.xs) {
                                Text(skill.category.iconName)
                                    .font(.system(size: 16))
                                Text(skill.name)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(viewModel.skillRatings[skill.id] ?? 50))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppColors.primary)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            Slider(
                                value: Binding(
                                    get: { viewModel.skillRatings[skill.id] ?? 50 },
                                    set: { viewModel.skillRatings[skill.id] = $0 }
                                ),
                                in: 0...100,
                                step: 1
                            )
                            .tint(AppColors.primary)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)

                        if skill.id != selectedSkills.last?.id {
                            Divider().padding(.horizontal, AppSpacing.sm)
                        }
                    }
                }
                .padding(.bottom, AppSpacing.xxs)
            }
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("Notes")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("Optional")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)

            Divider().padding(.horizontal, AppSpacing.sm)

            TextField("How did it go?", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .padding(AppSpacing.sm)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: floatShadow1.0, radius: floatShadow1.1, x: 0, y: floatShadow1.2)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            Task { await viewModel.save() }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Log Session")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if viewModel.canSave {
                        AnyView(ZStack {
                            LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDark],
                                           startPoint: .top, endPoint: .bottom)
                            LinearGradient(colors: [.white.opacity(0.16), .clear],
                                           startPoint: .top,
                                           endPoint: .init(x: 0.5, y: 0.55))
                        })
                    } else {
                        AnyView(AppColors.lockedGray)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
            .shadow(color: viewModel.canSave ? AppColors.primary.opacity(0.30) : .clear, radius: 0, y: 3)
            .shadow(color: viewModel.canSave ? AppColors.primary.opacity(0.14) : .clear, radius: 8, y: 5)
        }
        .buttonStyle(.pressable)
        .disabled(!viewModel.canSave)
    }
}

// MARK: - Skill Selection Row

private struct SkillSelectionRow: View {
    let skill: Skill
    let isSelected: Bool
    @Binding var rating: Double
    let drills: [Drill]
    let completedDrillIds: Set<UUID>
    let isDrillSession: Bool
    let onToggle: () -> Void
    let onToggleDrill: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(isSelected ? AppColors.primary : AppColors.separator)

                    Text(skill.category.iconName)
                        .font(.system(size: 16))

                    Text(skill.name)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    if isSelected {
                        Text("\(Int(rating))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.primary)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isSelected {
                VStack(spacing: AppSpacing.xxs) {
                    Slider(value: $rating, in: 0...100, step: 1)
                        .tint(AppColors.primary)
                        .padding(.horizontal, AppSpacing.sm)

                    if isDrillSession && !drills.isEmpty {
                        Divider().padding(.horizontal, AppSpacing.sm)
                        ForEach(drills) { drill in
                            let isCompleted = completedDrillIds.contains(drill.id)
                            Button { onToggleDrill(drill.id) } label: {
                                HStack(spacing: AppSpacing.xxs) {
                                    Image(systemName: isCompleted ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 15))
                                        .foregroundStyle(isCompleted ? AppColors.successGreen : AppColors.lockedGray)
                                    Text(drill.name)
                                        .font(.system(size: 13, design: .rounded))
                                        .foregroundStyle(isCompleted ? AppColors.textSecondary : AppColors.textPrimary)
                                        .strikethrough(isCompleted)
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.bottom, AppSpacing.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isSelected {
                Divider().padding(.horizontal, AppSpacing.sm)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

#Preview {
    let deps = DependencyContainer()
    let vm = LogSessionViewModel(
        skillRepository: deps.skillRepository,
        sessionRepository: deps.sessionRepository,
        journalEntryRepository: deps.journalEntryRepository,
        skillRatingRepository: deps.skillRatingRepository,
        drillRepository: deps.drillRepository
    )
    LogSessionView(viewModel: vm)
}
