import SwiftUI

/// One-time modal for existing users to set their goal DUPR and pillar confidences.
/// Shown after upgrade when hasCompletedOnboarding == true but goalDUPR == nil.
struct GoalDUPRPromptView: View {
    var onComplete: () -> Void

    @State private var selectedGoal: String?
    @State private var step = 0 // 0 = goal DUPR, 1 = pillar confidences
    @State private var pillarValues: [SkillPillar: Double] = [
        .consistency: 5, .transition: 4, .attack: 3, .movement: 4, .strategy: 3
    ]
    @State private var isSeeding = false

    var body: some View {
        VStack(spacing: 0) {
            if step == 0 {
                goalStep
            } else {
                confidenceStep
            }
        }
        .background(AppColors.background)
    }

    // MARK: - Step 1: Goal DUPR

    private var goalStep: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 44))
                .foregroundStyle(AppColors.primary)

            Text("Set your goal")
                .font(AppTypography.largeTitle)
                .multilineTextAlignment(.center)

            Text("What DUPR level are you working toward? We'll set benchmark targets for each skill.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppSpacing.xs) {
                goalCard("3.0", subtitle: "Getting started", isSelected: selectedGoal == "3.0") {
                    selectedGoal = "3.0"
                }
                goalCard("3.5", subtitle: "Solid recreational", isSelected: selectedGoal == "3.5") {
                    selectedGoal = "3.5"
                }
                goalCard("4.0", subtitle: "Competitive club player", isSelected: selectedGoal == "4.0") {
                    selectedGoal = "4.0"
                }
                goalCard("4.5", subtitle: "Advanced competitor", isSelected: selectedGoal == "4.5") {
                    selectedGoal = "4.5"
                }
                goalCard("5.0", subtitle: "Elite level", isSelected: selectedGoal == "5.0") {
                    selectedGoal = "5.0"
                }
            }

            if selectedGoal != nil {
                Button {
                    withAnimation { step = 1 }
                } label: {
                    Text("Next")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func goalCard(_ dupr: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(dupr)
                    .font(AppTypography.statMedium)
                    .foregroundStyle(isSelected ? .white : AppColors.primary)
                VStack(alignment: .leading) {
                    Text(subtitle)
                        .font(AppTypography.cardBody)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? AppColors.primary : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Pillar Confidences

    private var confidenceStep: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Text("Rate your confidence")
                .font(AppTypography.largeTitle)
                .multilineTextAlignment(.center)

            Text("How confident are you in each area? (1 = beginner, 10 = advanced)")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: AppSpacing.sm) {
                ForEach(SkillPillar.allCases) { pillar in
                    VStack(spacing: AppSpacing.xxxs) {
                        HStack {
                            Text(pillar.iconName)
                                .font(.title3)
                            Text(pillar.displayName)
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer()
                            Text("\(Int(pillarValues[pillar] ?? 5))")
                                .font(AppTypography.statMedium)
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 30)
                        }

                        Slider(
                            value: Binding(
                                get: { pillarValues[pillar] ?? 5 },
                                set: { pillarValues[pillar] = $0 }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .tint(AppColors.primary)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .neumorphicRaised(intensity: .subtle, cornerRadius: AppSpacing.cornerRadiusMd)

            Button {
                completeSetup()
            } label: {
                if isSeeding {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                } else {
                    Text("Get Started")
                        .font(AppTypography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
            }
            .buttonStyle(.plain)
            .disabled(isSeeding)

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Complete

    private func completeSetup() {
        guard let goal = selectedGoal else { return }
        isSeeding = true

        // Save goal DUPR
        PlayerProfile.saveGoalDUPR(goal)

        // Save pillar confidences
        var confidences: [String: Int] = [:]
        for (pillar, value) in pillarValues {
            confidences[pillar.rawValue] = Int(value)
        }
        PlayerProfile.savePillarConfidences(confidences)

        // Seed canonical skills
        Task {
            await DataMigrationService.seedCanonicalSkills(
                pillarConfidences: confidences,
                persistence: PersistenceController.shared
            )
            isSeeding = false
            onComplete()
        }
    }
}
