import SwiftUI

/// Sheet for updating a skill's confidence rating (1-10 slider with qualitative labels).
struct ConfidenceUpdateSheet: View {
    let skillName: String
    let currentConfidence: Int
    var onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedConfidence: Double

    init(skillName: String, currentConfidence: Int, onSave: @escaping (Int) -> Void) {
        self.skillName = skillName
        self.currentConfidence = currentConfidence
        self.onSave = onSave
        self._selectedConfidence = State(initialValue: Double(currentConfidence))
    }

    private var confidenceInt: Int {
        Int(selectedConfidence.rounded())
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Capsule()
                .fill(AppColors.separator)
                .frame(width: 36, height: 5)
                .padding(.top, AppSpacing.xs)

            Text("Update Confidence")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text(skillName)
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.textSecondary)

            // Large confidence number
            Text("\(confidenceInt)")
                .font(AppTypography.ratingLarge)
                .foregroundStyle(AppColors.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: confidenceInt)

            // Qualitative label
            Text(qualitativeLabel)
                .font(AppTypography.cardBody)
                .foregroundStyle(AppColors.textSecondary)

            // Slider
            VStack(spacing: AppSpacing.xxs) {
                Slider(value: $selectedConfidence, in: 1...10, step: 1)
                    .tint(AppColors.primary)

                HStack {
                    Text("1")
                        .font(AppTypography.pillLabel)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Text("10")
                        .font(AppTypography.pillLabel)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, AppSpacing.sm)

            // Change indicator
            if confidenceInt != currentConfidence {
                let delta = confidenceInt - currentConfidence
                HStack(spacing: 4) {
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    Text("\(abs(delta)) from current")
                }
                .font(AppTypography.cardCaption)
                .foregroundStyle(delta > 0 ? AppColors.successGreen : AppColors.coral)
            }

            Spacer()

            // Save button
            Button {
                onSave(confidenceInt)
                dismiss()
            } label: {
                Text("Save")
                    .font(AppTypography.buttonLabel)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
        }
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    private var qualitativeLabel: String {
        switch confidenceInt {
        case 1: return "No idea where to start"
        case 2: return "Aware but can't execute"
        case 3: return "Sometimes get it right"
        case 4: return "Inconsistent but improving"
        case 5: return "Can do it under no pressure"
        case 6: return "Reliable in practice"
        case 7: return "Works in most game situations"
        case 8: return "Consistent weapon"
        case 9: return "Advanced mastery"
        case 10: return "Automatic — second nature"
        default: return ""
        }
    }
}
