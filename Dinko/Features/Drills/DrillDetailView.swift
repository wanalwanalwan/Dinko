import SwiftUI

struct DrillDetailView: View {
    private let drillName: String
    private let skillName: String
    private let durationMinutes: Int
    private let priority: String
    private let drillDescription: String
    private let equipment: String
    private let playerCount: Int
    private let reason: String
    private let targetSubskill: String?
    private let targetReps: Int
    private let completedReps: Int
    private let onComplete: () async -> Void
    private let onSkip: (() async -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Existing init for HomeRecommendedDrill (HomeView compatibility)
    init(drill: HomeRecommendedDrill, onComplete: @escaping () async -> Void) {
        self.drillName = drill.drillName
        self.skillName = drill.skillName
        self.durationMinutes = drill.durationMinutes
        self.priority = drill.priority
        self.drillDescription = drill.drillDescription
        self.equipment = drill.equipment
        self.playerCount = drill.playerCount
        self.reason = drill.reason
        self.targetSubskill = drill.targetSubskill
        self.targetReps = 1
        self.completedReps = 0
        self.onComplete = onComplete
        self.onSkip = nil
    }

    // Init for Drill type (DrillQueueView)
    init(drill: Drill, skillName: String, onComplete: @escaping () async -> Void, onSkip: @escaping () async -> Void) {
        self.drillName = drill.name
        self.skillName = skillName
        self.durationMinutes = drill.durationMinutes
        self.priority = drill.priority
        self.drillDescription = drill.drillDescription
        self.equipment = drill.equipment
        self.playerCount = drill.playerCount
        self.reason = drill.reason
        self.targetSubskill = drill.targetSubskill
        self.targetReps = drill.targetReps
        self.completedReps = drill.completedReps
        self.onComplete = onComplete
        self.onSkip = onSkip
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    headerSection

                    if !descriptionSteps.isEmpty {
                        howItWorksSection
                    }

                    if !reasonBullets.isEmpty {
                        coachingTipsSection
                    }

                    if playerCount > 1 || targetReps > 1 {
                        setupSection
                    }


                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, 120)
            }

            stickyActionBar
        }
        .background(AppColors.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "figure.pickleball")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.teal)

            Text(drillName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Metadata pills
            HStack(spacing: AppSpacing.xxs) {
                metadataPill(emoji: "\u{23F1}", text: "\(durationMinutes) min")
                if let subskill = targetSubskill {
                    metadataPill(emoji: "\u{1F3AF}", text: subskill)
                }
                metadataPill(emoji: "\u{1F9E0}", text: skillName)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    private func metadataPill(emoji: String, text: String) -> some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, 6)
        .background(AppColors.primaryTint)
        .clipShape(Capsule())
    }

    // MARK: - How It Works

    private var descriptionSteps: [String] {
        drillDescription
            .components(separatedBy: ". ")
            .flatMap { $0.components(separatedBy: ".\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
            .filter { !$0.isEmpty }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("HOW IT WORKS")

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(Array(descriptionSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(AppColors.teal)
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Coaching Tips

    private var reasonBullets: [String] {
        reason
            .components(separatedBy: ". ")
            .flatMap { $0.components(separatedBy: ".\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
            .filter { !$0.isEmpty }
    }

    private var coachingTipsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("COACHING TIPS")

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(reasonBullets, id: \.self) { tip in
                    HStack(alignment: .top, spacing: AppSpacing.xxs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.warningOrange)
                            .frame(width: 18)
                            .padding(.top, 2)

                        Text(tip)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    // MARK: - Setup

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            sectionHeader("SETUP")

            VStack(spacing: AppSpacing.xxs) {
                if playerCount > 1 {
                    setupRow(icon: "person.2.fill", label: "Players", value: "\(playerCount)")
                }
                if targetReps > 1 {
                    setupRow(icon: "arrow.counterclockwise", label: "Reps", value: "\(targetReps) total")
                }
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        }
    }

    private func setupRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.teal)
                .frame(width: 22)

            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .tracking(1)
    }

    // MARK: - Sticky Action Bar

    private var stickyActionBar: some View {
        VStack(spacing: AppSpacing.xxs) {
            if targetReps > 1 {
                Text("Rep \(completedReps + 1) of \(targetReps)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.coral)
            }

            Button {
                Task {
                    await onComplete()
                    dismiss()
                }
            } label: {
                Text("START DRILL")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if let onSkip {
                Button {
                    Task {
                        await onSkip()
                        dismiss()
                    }
                } label: {
                    Text("Skip")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.top, AppSpacing.xs)
        .padding(.bottom, AppSpacing.lg)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
