import SwiftUI

struct ClarificationCard: View {
    let preview: ClarificationPreview
    let onSelectOption: (String) -> Void
    let onDismiss: () -> Void

    private var isPending: Bool {
        if case .pending = preview.state { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Label("Quick Question", systemImage: "questionmark.circle.fill")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.teal)
                Spacer()
                if isPending {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(6)
                            .background(Color(hex: "F4F6F8"))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Dismiss question")
                }
            }

            Divider()

            if case .dismissed = preview.state {
                Text("Skipped")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                // Question
                Text(preview.question)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Options
                VStack(spacing: AppSpacing.xxs) {
                    ForEach(preview.options) { option in
                        optionRow(option)
                    }
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clarification: \(preview.question)")
    }

    @ViewBuilder
    private func optionRow(_ option: ClarificationOption) -> some View {
        let isSelected: Bool = {
            if case .selected(let id) = preview.state { return id == option.id }
            if case .resolved = preview.state { return false }
            return false
        }()
        let isDisabled: Bool = {
            if case .pending = preview.state { return false }
            return true
        }()

        Button {
            onSelectOption(option.id)
        } label: {
            HStack {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.teal)
                }
                Text(option.label)
                    .font(AppTypography.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? AppColors.teal : AppColors.textPrimary)
                Spacer()
                if !isDisabled && !isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(
                isSelected
                    ? AppColors.teal.opacity(0.1)
                    : Color(hex: "F4F6F8")
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDisabled)
        .opacity(isDisabled && !isSelected ? 0.5 : 1.0)
    }
}
