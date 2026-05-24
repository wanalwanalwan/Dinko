import SwiftUI

struct SkillCoachingView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: SkillCoachingViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    loadingState
                } else if let error = viewModel.errorMessage, viewModel.gameTips.isEmpty && viewModel.drills.isEmpty {
                    errorState(error)
                } else {
                    resultsContent
                }
            }
            .background(AppColors.background)
            .navigationTitle("AI Coaching")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }

                if !viewModel.isLoading && (!viewModel.gameTips.isEmpty || !viewModel.drills.isEmpty) {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await viewModel.generateCoaching() }
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppColors.teal)
                        }
                        .accessibilityLabel("Regenerate coaching")
                    }
                }
            }
        }
        .task {
            await viewModel.generateCoaching()
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            CoachMascot(state: .thinking, size: 80)

            Text("Analyzing your skill...")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text("Building personalized tips and drills")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            ProgressView()
                .tint(AppColors.teal)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.warningOrange)

            Text("Something went wrong")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Button {
                Task { await viewModel.generateCoaching() }
            } label: {
                Text("Try Again")
                    .font(AppTypography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.teal)
                    .clipShape(Capsule())
            }
            .buttonStyle(.pressable)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    private var resultsContent: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                if !viewModel.gameTips.isEmpty {
                    gameTipsSection
                }

                if !viewModel.drills.isEmpty {
                    drillsSection
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Game Tips

    private var gameTipsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.warningOrange)

                Text("GAME TIPS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)

            ForEach(viewModel.gameTips) { tip in
                gameTipCard(tip)
            }
        }
    }

    private func gameTipCard(_ tip: GameTip) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(tip.title)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textPrimary)

            Text(tip.tip)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary.opacity(0.8))

            HStack(spacing: AppSpacing.xxxs) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.warningOrange)

                Text(tip.situation)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.top, AppSpacing.xxxs)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    // MARK: - Drills

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "figure.run")
                    .font(.caption)
                    .foregroundStyle(AppColors.teal)

                Text("DRILL SUGGESTIONS")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.sm)

            ForEach(Array(viewModel.drills.enumerated()), id: \.element.name) { index, drill in
                drillRow(drill, index: index)
            }
        }
    }

    private func drillRow(_ drill: DrillRecommendation, index: Int) -> some View {
        let isAdded = viewModel.addedDrillIndices.contains(index)

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    Text(drill.name)
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xxxs) {
                        Text("\(drill.durationMinutes) min")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        if let subskill = drill.targetSubskill {
                            Text("\u{2022}")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Text(subskill)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.teal)
                        }
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.addDrill(at: index) }
                } label: {
                    if isAdded {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.successGreen)
                    } else {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.teal)
                    }
                }
                .disabled(isAdded)
                .buttonStyle(.pressable)
            }

            Text(drill.reason)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .italic()
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }
}
