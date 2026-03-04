import SwiftUI

struct SkillCreationCard: View {
    let preview: SkillCreationPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onCategoryChanged: (SkillCategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            Label("New Skill", systemImage: "plus.circle.fill")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.teal)

            Divider()

            // Skill name
            HStack(spacing: AppSpacing.xxs) {
                Text(preview.category.iconName)
                    .font(.system(size: 20))
                Text(preview.skillName)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Category picker
            if case .pending = preview.confirmState {
                HStack {
                    Text("Category")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Picker("Category", selection: Binding(
                        get: { preview.category },
                        set: { onCategoryChanged($0) }
                    )) {
                        ForEach(SkillCategory.allCases) { category in
                            Text("\(category.iconName) \(category.displayName)")
                                .tag(category)
                        }
                    }
                    .tint(AppColors.teal)
                }
            } else {
                HStack(spacing: AppSpacing.xxs) {
                    Text("Category:")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(preview.category.iconName) \(preview.category.displayName)")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            Divider()

            // Action Buttons
            actionButtons
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch preview.confirmState {
        case .pending:
            HStack(spacing: AppSpacing.xs) {
                Button(action: onConfirm) {
                    Label("Add Skill", systemImage: "plus")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.teal)

                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppTypography.callout)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.bordered)
            }

        case .confirming:
            HStack {
                Spacer()
                ProgressView()
                    .padding(.trailing, AppSpacing.xxs)
                Text("Creating...")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
            .padding(.vertical, AppSpacing.xxs)

        case .confirmed:
            Label("Skill added", systemImage: "checkmark.circle.fill")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.successGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxs)

        case .failed(let message):
            VStack(spacing: AppSpacing.xxs) {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.coral)

                Button(action: onConfirm) {
                    Label("Retry", systemImage: "arrow.counterclockwise")
                        .font(AppTypography.callout)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.coral)
            }
        }
    }
}
