import SwiftUI

struct ProgramTemplateCard: View {
    let template: ProgramTemplate
    let isPro: Bool
    var onTap: () -> Void

    private var isLocked: Bool {
        template.isPremium && !isPro
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                // Title row
                HStack {
                    Text(template.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if isLocked {
                        ProBadge(fontSize: 9)
                    }
                }

                // Author + difficulty
                HStack(spacing: 8) {
                    Text(template.author)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)

                    difficultyBadge
                }

                // Metadata
                HStack(spacing: 12) {
                    Label("\(template.totalWeeks) weeks", systemImage: "calendar")
                    Label("\(template.sessionsPerWeek)x/week", systemImage: "figure.run")
                }
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)

                // Skill focus
                if !template.skillFocus.isEmpty {
                    Text(template.skillFocus)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }

                // Description
                Text(template.templateDescription)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            .padding(AppSpacing.sm)
            .neumorphicRaised(cornerRadius: AppSpacing.cornerRadiusMd)
            .opacity(isLocked ? 0.85 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var difficultyBadge: some View {
        Text(template.difficulty.rawValue.capitalized)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(difficultyColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(difficultyColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var difficultyColor: Color {
        switch template.difficulty {
        case .beginner: AppColors.successGreen
        case .intermediate: AppColors.warningOrange
        case .advanced: AppColors.coral
        }
    }
}
