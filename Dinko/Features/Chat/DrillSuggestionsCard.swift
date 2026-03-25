import SwiftUI

struct DrillSuggestionsCard: View {
    let preview: DrillSuggestionsPreview
    let onAddDrill: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            Label("Drill Recommendations", systemImage: "figure.pickleball")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.teal)

            // Chat text
            if !preview.chatText.isEmpty {
                Text(preview.chatText)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Drill list
            VStack(spacing: AppSpacing.xs) {
                ForEach(Array(preview.drills.enumerated()), id: \.offset) { index, drill in
                    drillRow(drill, index: index)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drill suggestions: \(preview.drills.count) drills")
    }

    @ViewBuilder
    private func drillRow(_ drill: DrillRecommendation, index: Int) -> some View {
        let isAdded = preview.addedDrillIndices.contains(index)

        VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drill.name)
                        .font(AppTypography.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: AppSpacing.xxs) {
                        Label("\(drill.durationMinutes)m", systemImage: "clock")
                        if let subskill = drill.targetSubskill, !subskill.isEmpty {
                            Text("·")
                            Text(subskill)
                        }
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    onAddDrill(index)
                } label: {
                    if isAdded {
                        Label("Added", systemImage: "checkmark")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.successGreen)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxxs)
                            .background(AppColors.successGreen.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Label("Add", systemImage: "plus")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.teal)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxxs)
                            .background(AppColors.teal.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .disabled(isAdded)
            }

            Text(drill.reason)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.xs)
        .background(Color(hex: "F4F6F8"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
