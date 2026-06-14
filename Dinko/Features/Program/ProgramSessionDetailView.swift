import SwiftUI

struct ProgramSessionDetailView: View {
    @State private var viewModel: ProgramSessionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    var onSessionComplete: (() -> Void)?

    init(
        session: ProgramSession,
        programRepository: ProgramRepository,
        skillRepository: SkillRepository,
        skillRatingRepository: SkillRatingRepository,
        onSessionComplete: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: ProgramSessionDetailViewModel(
            session: session,
            programRepository: programRepository,
            skillRepository: skillRepository,
            skillRatingRepository: skillRatingRepository
        ))
        self.onSessionComplete = onSessionComplete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                // Session header
                sessionHeader

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xl)
                } else if viewModel.drills.isEmpty && viewModel.session.status == .available {
                    // No drills yet — show focus guidance + generate button
                    focusGuidanceSection
                } else {
                    // Drills list
                    ForEach(viewModel.drills) { drill in
                        ProgramDrillRow(
                            drill: drill,
                            onComplete: { Task { await viewModel.completeDrill(drill.id) } },
                            onSkip: { Task { await viewModel.skipDrill(drill.id) } },
                            onIncrementRep: { Task { await viewModel.incrementRep(drill.id) } }
                        )
                    }
                }

                // Complete session button
                if viewModel.session.status == .available {
                    Button {
                        Task {
                            await viewModel.completeSession()
                            onSessionComplete?()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Complete Session")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.allDrillsComplete ? AppColors.successGreen : AppColors.lockedGray)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                    }
                    .disabled(!viewModel.allDrillsComplete)
                    .buttonStyle(.pressable)
                    .padding(.top, AppSpacing.sm)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .navigationTitle(viewModel.session.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDrills()
        }
        .overlay {
            if viewModel.showCelebration {
                celebrationOverlay
            }
        }
    }

    private var sessionHeader: some View {
        VStack(spacing: AppSpacing.xxs) {
            if !viewModel.session.focus.isEmpty {
                Text(viewModel.session.focus)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            }

            HStack(spacing: AppSpacing.sm) {
                Label("\(viewModel.session.estimatedMinutes) min", systemImage: "clock")
                if !viewModel.drills.isEmpty {
                    Label("\(viewModel.drills.count) drills", systemImage: "list.bullet")
                }
                if viewModel.completedDrillCount > 0 {
                    Label("\(viewModel.completedDrillCount) done", systemImage: "checkmark")
                }
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)

            if viewModel.totalMinutesRemaining > 0 && viewModel.session.status == .available {
                Text("\(viewModel.totalMinutesRemaining) min remaining")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity)
        .neumorphicTinted(color: AppColors.primary, tintOpacity: 0.04, borderOpacity: 0.1)
    }

    private var focusGuidanceSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Focus text card
            if !viewModel.session.focus.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label("Today's Focus", systemImage: "target")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primary)

                    Text(viewModel.session.focus)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .neumorphicTinted(color: AppColors.primary, tintOpacity: 0.06, borderOpacity: 0.12)
            }

            // Generate Drills button
            Button {
                Task { await viewModel.generateDrills() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isGeneratingDrills {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                    }
                    Text(viewModel.isGeneratingDrills ? "Generating Drills..." : "Generate Drills")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
            }
            .disabled(viewModel.isGeneratingDrills)
            .buttonStyle(.pressable)

            // Alternative: just practice with focus
            Text("Or just go practice with this focus and complete the session when done.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.sm)
        }
        .padding(.top, AppSpacing.sm)
    }

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(AppColors.trophyGold)

                Text("Session Complete!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Great work! Keep up the momentum.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, 12)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressable)
            }
            .padding(AppSpacing.lg)
            .neumorphicRaised(intensity: .prominent)
        }
    }
}
