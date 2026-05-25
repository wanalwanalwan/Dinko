import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0
    @State private var isCompleting = false

    var onComplete: () -> Void

    private let totalSteps = 7

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                duprStep.tag(0)
                playStyleStep.tag(1)
                gameFormatStep.tag(2)
                primaryGoalStep.tag(3)
                frequencyStep.tag(4)
                ageRangeStep.tag(5)
                drillPreferencesStep.tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            dotIndicator
                .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
    }

    // MARK: - Dot Indicator

    private var dotIndicator: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? AppColors.primary : AppColors.primary.opacity(0.25))
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
                selectionCard("Beginner (2.0-3.0)", icon: "figure.walk", isSelected: viewModel.duprRange == "Beginner (2.0-3.0)") {
                    viewModel.duprRange = "Beginner (2.0-3.0)"
                    advanceAfterDelay()
                }
                selectionCard("Intermediate (3.0-4.0)", icon: "figure.run", isSelected: viewModel.duprRange == "Intermediate (3.0-4.0)") {
                    viewModel.duprRange = "Intermediate (3.0-4.0)"
                    advanceAfterDelay()
                }
                selectionCard("Advanced (4.0-5.0)", icon: "figure.highintensity.intervaltraining", isSelected: viewModel.duprRange == "Advanced (4.0-5.0)") {
                    viewModel.duprRange = "Advanced (4.0-5.0)"
                    advanceAfterDelay()
                }
                selectionCard("Pro (5.0+)", icon: "trophy.fill", isSelected: viewModel.duprRange == "Pro (5.0+)") {
                    viewModel.duprRange = "Pro (5.0+)"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 2: Play Style

    private var playStyleStep: some View {
        stepContainer(
            title: "What's your play style?",
            subtitle: "We'll tailor coaching to complement your strengths."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Banger", icon: "bolt.fill", isSelected: viewModel.playStyle == "Banger") {
                    viewModel.playStyle = "Banger"
                    advanceAfterDelay()
                }
                selectionCard("Dinker", icon: "hand.raised.fill", isSelected: viewModel.playStyle == "Dinker") {
                    viewModel.playStyle = "Dinker"
                    advanceAfterDelay()
                }
                selectionCard("All-Court", icon: "arrow.left.and.right", isSelected: viewModel.playStyle == "All-Court") {
                    viewModel.playStyle = "All-Court"
                    advanceAfterDelay()
                }
                selectionCard("Counter-Puncher", icon: "shield.fill", isSelected: viewModel.playStyle == "Counter-Puncher") {
                    viewModel.playStyle = "Counter-Puncher"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 3: Game Format

    private var gameFormatStep: some View {
        stepContainer(
            title: "Singles or doubles?",
            subtitle: "We'll focus drills on your preferred format."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Singles", icon: "person.fill", isSelected: viewModel.gameFormat == "Singles") {
                    viewModel.gameFormat = "Singles"
                    advanceAfterDelay()
                }
                selectionCard("Doubles", icon: "person.2.fill", isSelected: viewModel.gameFormat == "Doubles") {
                    viewModel.gameFormat = "Doubles"
                    advanceAfterDelay()
                }
                selectionCard("Both", icon: "person.3.fill", isSelected: viewModel.gameFormat == "Both") {
                    viewModel.gameFormat = "Both"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 4: Primary Goal

    private var primaryGoalStep: some View {
        stepContainer(
            title: "What's your #1 goal?",
            subtitle: "This helps us prioritize what matters most to you."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Compete in tournaments", icon: "trophy.fill", isSelected: viewModel.primaryGoal == "Compete in tournaments") {
                    viewModel.primaryGoal = "Compete in tournaments"
                    advanceAfterDelay()
                }
                selectionCard("Improve DUPR", icon: "chart.line.uptrend.xyaxis", isSelected: viewModel.primaryGoal == "Improve DUPR") {
                    viewModel.primaryGoal = "Improve DUPR"
                    advanceAfterDelay()
                }
                selectionCard("Stay active", icon: "heart.fill", isSelected: viewModel.primaryGoal == "Stay active") {
                    viewModel.primaryGoal = "Stay active"
                    advanceAfterDelay()
                }
                selectionCard("Beat my friends", icon: "figure.pickleball", isSelected: viewModel.primaryGoal == "Beat my friends") {
                    viewModel.primaryGoal = "Beat my friends"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 5: Training Frequency

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

    // MARK: - Step 6: Age Range

    private var ageRangeStep: some View {
        stepContainer(
            title: "What's your age range?",
            subtitle: "We'll adjust drill intensity and recovery recommendations."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Under 30", icon: "hare.fill", isSelected: viewModel.ageRange == "Under 30") {
                    viewModel.ageRange = "Under 30"
                    advanceAfterDelay()
                }
                selectionCard("30-50", icon: "figure.walk", isSelected: viewModel.ageRange == "30-50") {
                    viewModel.ageRange = "30-50"
                    advanceAfterDelay()
                }
                selectionCard("50+", icon: "figure.and.child.holdinghands", isSelected: viewModel.ageRange == "50+") {
                    viewModel.ageRange = "50+"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 7: Drill Preferences (Multi-select)

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
                                .background(AppColors.primary)
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
                    .foregroundStyle(isSelected ? .white : AppColors.primary)
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
            .background(isSelected ? AppColors.primary : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.xs)
                    .strokeBorder(isSelected ? AppColors.primary : Color.clear, lineWidth: 2)
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
                .background(isSelected ? AppColors.primary : AppColors.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? AppColors.primary : AppColors.separator, lineWidth: 1)
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

        viewModel.completeOnboarding()
        onComplete()
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
