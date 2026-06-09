import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var currentStep = 0
    @State private var isCompleting = false
    @State private var duprService = DUPRService.shared
    @State private var showDUPRSheet = false
    @State private var showManualRangePicker = false

    var onComplete: () -> Void

    private let totalSteps = 12
    @State private var selectedSkills: [PendingFocusSkill] = []
    @State private var customSkillInput = ""
    @State private var showCustomInput = false
    @State private var customSkillList: [SuggestedSkill] = []

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                duprStep.tag(0)
                playStyleStep.tag(1)
                gameFormatStep.tag(2)
                primaryGoalStep.tag(3)
                frequencyStep.tag(4)
                ageRangeStep.tag(5)
                practiceSettingStep.tag(6)
                partnerAvailabilityStep.tag(7)
                experienceLevelStep.tag(8)
                injuriesStep.tag(9)
                drillPreferencesStep.tag(10)
                focusSkillsStep.tag(11)
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

    // MARK: - Step 1: DUPR Connect + Range

    private var duprStep: some View {
        stepContainer(
            title: "What's your skill level?",
            subtitle: duprService.isConnected
                ? "Your real DUPR rating is synced."
                : "Connect DUPR for your real rating, or pick your level."
        ) {
            VStack(spacing: AppSpacing.sm) {
                if duprService.isConnected, let profile = duprService.profile {
                    // Connected — show rating and continue button
                    VStack(spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppColors.successGreen)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("DUPR Connected")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text("ID: \(profile.duprId)")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.successGreen.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))

                        HStack(spacing: AppSpacing.md) {
                            duprRatingChip(label: "Singles", value: profile.formattedSingles)
                            duprRatingChip(label: "Doubles", value: profile.formattedDoubles)
                        }

                        Button {
                            advanceAfterDelay()
                        } label: {
                            Text("Continue")
                                .font(AppTypography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, AppSpacing.xxs)
                    }
                } else {
                    // Not connected — offer DUPR connect or manual picker
                    Button {
                        showDUPRSheet = true
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Connect DUPR Account")
                                    .font(AppTypography.headline)
                                    .foregroundStyle(.white)
                                Text("Get your real, official rating")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(AppSpacing.sm)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showManualRangePicker.toggle()
                        }
                    } label: {
                        HStack {
                            Text(showManualRangePicker ? "Hide manual entry" : "Enter level manually instead")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                            Image(systemName: showManualRangePicker ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if showManualRangePicker {
                        VStack(spacing: AppSpacing.xxs) {
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
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                }
            }
        }
        .sheet(isPresented: $showDUPRSheet) {
            NavigationStack {
                DUPRConnectSheet(duprService: duprService, onConnected: {
                    showDUPRSheet = false
                    if let profile = duprService.profile {
                        viewModel.duprRange = duprRangeFromRating(profile.singlesRating ?? profile.doublesRating)
                    }
                })
                .navigationTitle("Connect DUPR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showDUPRSheet = false }
                            .foregroundStyle(AppColors.primary)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func duprRatingChip(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primary)
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func duprRangeFromRating(_ rating: Double?) -> String {
        guard let rating else { return "Intermediate (3.0-4.0)" }
        switch rating {
        case ..<3.0: return "Beginner (2.0-3.0)"
        case 3.0..<4.0: return "Intermediate (3.0-4.0)"
        case 4.0..<5.0: return "Advanced (4.0-5.0)"
        default: return "Pro (5.0+)"
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

    // MARK: - Step 7: Practice Setting

    private var practiceSettingStep: some View {
        stepContainer(
            title: "Where do you usually practice?",
            subtitle: "We'll suggest drills that fit your environment."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Public courts", icon: "tennisball.fill", isSelected: viewModel.practiceSetting == "Public courts") {
                    viewModel.practiceSetting = "Public courts"
                    advanceAfterDelay()
                }
                selectionCard("Club or rec center", icon: "building.2", isSelected: viewModel.practiceSetting == "Club or rec center") {
                    viewModel.practiceSetting = "Club or rec center"
                    advanceAfterDelay()
                }
                selectionCard("At home or driveway", icon: "house", isSelected: viewModel.practiceSetting == "At home or driveway") {
                    viewModel.practiceSetting = "At home or driveway"
                    advanceAfterDelay()
                }
                selectionCard("Varies", icon: "arrow.triangle.swap", isSelected: viewModel.practiceSetting == "Varies") {
                    viewModel.practiceSetting = "Varies"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 8: Partner Availability

    private var partnerAvailabilityStep: some View {
        stepContainer(
            title: "Do you have a practice partner?",
            subtitle: "We'll match drills to solo or partner practice."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Yes, always", icon: "person.2.fill", isSelected: viewModel.partnerAvailability == "Yes, always") {
                    viewModel.partnerAvailability = "Yes, always"
                    advanceAfterDelay()
                }
                selectionCard("Sometimes", icon: "person.2.wave.2", isSelected: viewModel.partnerAvailability == "Sometimes") {
                    viewModel.partnerAvailability = "Sometimes"
                    advanceAfterDelay()
                }
                selectionCard("Mostly solo", icon: "person.fill", isSelected: viewModel.partnerAvailability == "Mostly solo") {
                    viewModel.partnerAvailability = "Mostly solo"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 9: Experience Level

    private var experienceLevelStep: some View {
        stepContainer(
            title: "How long have you been playing?",
            subtitle: "This helps us calibrate drill complexity."
        ) {
            VStack(spacing: AppSpacing.xs) {
                selectionCard("Just started", icon: "leaf", isSelected: viewModel.experienceLevel == "Just started") {
                    viewModel.experienceLevel = "Just started"
                    advanceAfterDelay()
                }
                selectionCard("Under 1 year", icon: "clock", isSelected: viewModel.experienceLevel == "Under 1 year") {
                    viewModel.experienceLevel = "Under 1 year"
                    advanceAfterDelay()
                }
                selectionCard("1-3 years", icon: "calendar", isSelected: viewModel.experienceLevel == "1-3 years") {
                    viewModel.experienceLevel = "1-3 years"
                    advanceAfterDelay()
                }
                selectionCard("3+ years", icon: "star", isSelected: viewModel.experienceLevel == "3+ years") {
                    viewModel.experienceLevel = "3+ years"
                    advanceAfterDelay()
                }
            }
        }
    }

    // MARK: - Step 10: Injuries

    private var injuriesStep: some View {
        stepContainer(
            title: "Any injuries or limitations?",
            subtitle: "We'll avoid drills that could aggravate them."
        ) {
            VStack(spacing: AppSpacing.sm) {
                let options = ["None", "Shoulder", "Knee", "Back", "Wrist", "Other"]

                FlowLayout(spacing: AppSpacing.xxs) {
                    ForEach(options, id: \.self) { option in
                        pillButton(option, isSelected: viewModel.injuries.contains(option)) {
                            if option == "None" {
                                if viewModel.injuries.contains("None") {
                                    viewModel.injuries.remove("None")
                                } else {
                                    viewModel.injuries = ["None"]
                                }
                            } else {
                                viewModel.injuries.remove("None")
                                if viewModel.injuries.contains(option) {
                                    viewModel.injuries.remove(option)
                                } else {
                                    viewModel.injuries.insert(option)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: AppSpacing.xs) {
                    if !viewModel.injuries.isEmpty {
                        Button {
                            advanceAfterDelay()
                        } label: {
                            Text("Continue")
                                .font(AppTypography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        advanceAfterDelay()
                    } label: {
                        Text("Skip")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: viewModel.injuries.isEmpty ? .infinity : nil)
                            .padding(.vertical, AppSpacing.sm)
                            .padding(.horizontal, viewModel.injuries.isEmpty ? 0 : AppSpacing.lg)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, AppSpacing.xs)
            }
        }
    }

    // MARK: - Step 11: Drill Preferences (Multi-select)

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

    // MARK: - Step 12: Focus Skills

    private var focusSkillsStep: some View {
        stepContainer(
            title: "What skills do you want to work on?",
            subtitle: "Pick up to 3 in the order you want to tackle them. You can always change this later."
        ) {
            VStack(spacing: AppSpacing.sm) {
                // Selected preview
                if !selectedSkills.isEmpty {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(selectedSkills) { skill in
                            HStack(spacing: 5) {
                                Text("\(skill.priorityIndex + 1)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(AppColors.primary)
                                    .clipShape(Circle())
                                Text(skill.icon)
                                    .font(.system(size: 14))
                                Text(skill.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppColors.primary.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.xxs)
                }

                // Skill grid
                let allSuggested = Self.suggestedSkills + customSkillList
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.xxs) {
                    ForEach(allSuggested) { skill in
                        skillChip(skill)
                    }
                }

                // Add your own
                if showCustomInput {
                    HStack(spacing: AppSpacing.xxs) {
                        TextField("Skill name...", text: $customSkillInput)
                            .font(.system(size: 14, design: .rounded))
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .autocorrectionDisabled()

                        Button {
                            let trimmed = customSkillInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { showCustomInput = false; return }
                            let custom = SuggestedSkill(name: trimmed, icon: "✨", categoryRaw: "offense")
                            customSkillList.append(custom)
                            customSkillInput = ""
                            showCustomInput = false
                            toggleSkillSelection(custom)
                        } label: {
                            Text("Add")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(AppColors.primary)
                                .clipShape(Capsule())
                        }

                        Button { showCustomInput = false; customSkillInput = "" } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showCustomInput = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 14))
                            Text("Add your own skill")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(.plain)
                }

                // Continue / Skip
                HStack(spacing: AppSpacing.xs) {
                    if !selectedSkills.isEmpty {
                        Button { completeOnboarding() } label: {
                            Text("Continue")
                                .font(AppTypography.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                        }
                        .buttonStyle(.plain)
                        .disabled(isCompleting)
                    }

                    Button { completeOnboarding() } label: {
                        Text("Skip")
                            .font(AppTypography.headline)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: selectedSkills.isEmpty ? .infinity : nil)
                            .padding(.vertical, AppSpacing.sm)
                            .padding(.horizontal, selectedSkills.isEmpty ? 0 : AppSpacing.lg)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCompleting)
                }
                .padding(.top, AppSpacing.xxs)

                if isCompleting { ProgressView().padding(.top, AppSpacing.xxs) }
            }
        }
    }

    private func skillChip(_ skill: SuggestedSkill) -> some View {
        let selectedIndex = selectedSkills.firstIndex(where: { $0.name == skill.name })
        let isSelected = selectedIndex != nil

        return Button { toggleSkillSelection(skill) } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(skill.icon)
                        .font(.system(size: 22))
                    if let idx = selectedIndex {
                        Text("\(idx + 1)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(AppColors.primary)
                            .clipShape(Circle())
                            .offset(x: 6, y: -4)
                    }
                }
                Text(skill.name)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected ? AppColors.primary : AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .background(isSelected ? AppColors.primary.opacity(0.1) : AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private func toggleSkillSelection(_ skill: SuggestedSkill) {
        if let idx = selectedSkills.firstIndex(where: { $0.name == skill.name }) {
            selectedSkills.remove(at: idx)
            // Re-index remaining skills
            for i in selectedSkills.indices {
                selectedSkills[i].priorityIndex = i
            }
        } else {
            guard selectedSkills.count < 3 else { return }
            let pending = PendingFocusSkill(
                name: skill.name,
                icon: skill.icon,
                categoryRaw: skill.categoryRaw,
                priorityIndex: selectedSkills.count
            )
            selectedSkills.append(pending)
        }
    }

    static let suggestedSkills: [SuggestedSkill] = [
        SuggestedSkill(name: "Dinking",          icon: "🥒", categoryRaw: "dinking"),
        SuggestedSkill(name: "3rd Shot Drop",    icon: "⬇️", categoryRaw: "drops"),
        SuggestedSkill(name: "Reset",            icon: "🔄", categoryRaw: "defense"),
        SuggestedSkill(name: "Drive",            icon: "🚀", categoryRaw: "drives"),
        SuggestedSkill(name: "Serve",            icon: "🎯", categoryRaw: "serves"),
        SuggestedSkill(name: "Return of Serve",  icon: "↩️", categoryRaw: "strategy"),
        SuggestedSkill(name: "Speed-Up",         icon: "⚡", categoryRaw: "offense"),
        SuggestedSkill(name: "Volley",           icon: "🤚", categoryRaw: "offense"),
        SuggestedSkill(name: "Overhead",         icon: "💥", categoryRaw: "offense"),
        SuggestedSkill(name: "Lob",              icon: "🪂", categoryRaw: "offense"),
        SuggestedSkill(name: "Block",            icon: "🛡️", categoryRaw: "defense"),
        SuggestedSkill(name: "Footwork",         icon: "👟", categoryRaw: "drives"),
        SuggestedSkill(name: "Court Position",   icon: "📍", categoryRaw: "strategy"),
        SuggestedSkill(name: "Stacking",         icon: "♟️", categoryRaw: "strategy"),
        SuggestedSkill(name: "Erne",             icon: "✈️", categoryRaw: "offense"),
    ]

    // MARK: - Actions

    private func advanceAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { currentStep += 1 }
        }
    }

    private func completeOnboarding() {
        guard !isCompleting else { return }
        isCompleting = true

        viewModel.pendingFocusSkills = selectedSkills
        viewModel.completeOnboarding()
        onComplete()
    }
}

// MARK: - Suggested Skill

struct SuggestedSkill: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let categoryRaw: String
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
