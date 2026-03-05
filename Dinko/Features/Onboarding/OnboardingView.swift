import SwiftUI

struct OnboardingView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0
    @State private var isCompleting = false

    var onComplete: () -> Void

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                duprStep.tag(0)
                frequencyStep.tag(1)
                drillPreferencesStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            dotIndicator
                .padding(.bottom, AppSpacing.xl)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Dot Indicator

    private var dotIndicator: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? AppColors.teal : AppColors.teal.opacity(0.25))
                    .frame(width: index == currentStep ? 10 : 8, height: index == currentStep ? 10 : 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Step 1: DUPR Range

    private var duprStep: some View {
        stepContainer(
            title: "What's your skill level?",
            subtitle: "We'll personalize your experience based on your DUPR range."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Beginner (2.0-2.5)", icon: "figure.walk", isSelected: viewModel.duprRange == "Beginner (2.0-2.5)") {
                    viewModel.duprRange = "Beginner (2.0-2.5)"
                    advanceAfterDelay()
                }
                selectionCard("Intermediate (3.0-3.5)", icon: "figure.run", isSelected: viewModel.duprRange == "Intermediate (3.0-3.5)") {
                    viewModel.duprRange = "Intermediate (3.0-3.5)"
                    advanceAfterDelay()
                }
                selectionCard("Advanced (4.0-4.5)", icon: "figure.highintensity.intervaltraining", isSelected: viewModel.duprRange == "Advanced (4.0-4.5)") {
                    viewModel.duprRange = "Advanced (4.0-4.5)"
                    advanceAfterDelay()
                }
                selectionCard("Pro (5.0+)", icon: "trophy.fill", isSelected: viewModel.duprRange == "Pro (5.0+)") {
                    viewModel.duprRange = "Pro (5.0+)"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 2: Training Frequency

    private var frequencyStep: some View {
        stepContainer(
            title: "How often do you want to train?",
            subtitle: "We'll set your weekly goal to match."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("1-2x / week", icon: "calendar", isSelected: viewModel.trainingDaysPerWeek == 2) {
                    viewModel.trainingDaysPerWeek = 2
                    advanceAfterDelay()
                }
                selectionCard("3-4x / week", icon: "calendar.badge.plus", isSelected: viewModel.trainingDaysPerWeek == 4) {
                    viewModel.trainingDaysPerWeek = 4
                    advanceAfterDelay()
                }
                selectionCard("5+ / week", icon: "flame.fill", isSelected: viewModel.trainingDaysPerWeek == 5) {
                    viewModel.trainingDaysPerWeek = 5
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 3: Drill Preferences (Multi-select)

    private var drillPreferencesStep: some View {
        stepContainer(
            title: "What types of drills interest you?",
            subtitle: "Select all that apply, or skip."
        ) {
            VStack(spacing: AppSpacing.sm) {
                let types = ["Fitness", "Court IQ", "Technique", "Mental Game"]

                FlowLayout(spacing: AppSpacing.xxs) {
                    ForEach(types, id: \.self) { type in
                        pillButton(type, isSelected: viewModel.drillPreferences.contains(type)) {
                            if viewModel.drillPreferences.contains(type) {
                                viewModel.drillPreferences.remove(type)
                            } else {
                                viewModel.drillPreferences.insert(type)
                            }
                        }
                    }
                }

                HStack(spacing: AppSpacing.xs) {
                    if !viewModel.drillPreferences.isEmpty {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Continue")
                                .font(AppTypography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.teal)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                        .disabled(isCompleting)
                    }

                    Button {
                        completeOnboarding()
                    } label: {
                        Text("Skip")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: viewModel.drillPreferences.isEmpty ? .infinity : nil)
                            .padding(.vertical, AppSpacing.sm)
                            .padding(.horizontal, viewModel.drillPreferences.isEmpty ? 0 : AppSpacing.lg)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                    }
                    .disabled(isCompleting)
                }
                .padding(.top, AppSpacing.xs)

                if isCompleting {
                    ProgressView()
                        .padding(.top, AppSpacing.xxs)
                }
            }
        }
    }

    // MARK: - Shared Components

    private func stepContainer(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()

            Text(title)
                .font(AppTypography.largeTitle)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, AppSpacing.xs)

            content()

            Spacer()
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func selectionCard(
        _ label: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? .white : AppColors.teal)
                    .frame(width: 28)

                Text(label)
                    .font(AppTypography.headline)
                    .foregroundStyle(isSelected ? .white : AppColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(AppSpacing.sm)
            .background(isSelected ? AppColors.teal : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.xs)
                    .strokeBorder(isSelected ? AppColors.teal : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func pillButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppTypography.callout)
                .foregroundStyle(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .background(isSelected ? AppColors.teal : AppColors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? AppColors.teal : AppColors.separator, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func advanceAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { currentStep += 1 }
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }
        isCompleting = true

        Task {
            do {
                try await viewModel.completeOnboarding(
                    skillRepo: dependencies.skillRepository,
                    ratingRepo: dependencies.skillRatingRepository
                )
            } catch {
                // Best-effort: still complete onboarding even if data save fails
            }
            onComplete()
        }
    }
}

// MARK: - Flow Layout for Pills

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    OnboardingView {
        print("Onboarding complete")
    }
}
