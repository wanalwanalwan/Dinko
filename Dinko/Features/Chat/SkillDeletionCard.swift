import SwiftUI

struct SkillDeletionCard: View {
    let preview: SkillDeletionPreview
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            Label("Delete Skill", systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.coral)

            Divider()

            // Skill name
            HStack(spacing: AppSpacing.xxs) {
                Image(systemName: "trash")
                    .foregroundStyle(AppColors.coral)
                Text(preview.skillName)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
            }

            // Subskills warning
            if !preview.subskillNames.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("These subskills will also be deleted:")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary)

                    ForEach(preview.subskillNames, id: \.self) { name in
                        HStack(spacing: AppSpacing.xxs) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppColors.coral.opacity(0.7))
                                .font(.system(size: 12))
                            Text(name)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textPrimary)
                        }
                    }
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
                    Label("Delete", systemImage: "trash")
                        .font(AppTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.coral)

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
                Text("Deleting...")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
            .padding(.vertical, AppSpacing.xxs)

        case .confirmed:
            Label("Skill deleted", systemImage: "checkmark.circle.fill")
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
