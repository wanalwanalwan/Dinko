import SwiftUI

struct RateSkillView: View {
    @Environment(\.dismiss) private var dismiss
    let skillName: String
    let currentRating: Int
    let onSave: (Int, String?) async -> Bool

    @State private var rating: Double
    @State private var notes: String = ""
    @State private var isSaving = false

    init(skillName: String, currentRating: Int, onSave: @escaping (Int, String?) async -> Bool) {
        self.skillName = skillName
        self.currentRating = currentRating
        self.onSave = onSave
        self._rating = State(initialValue: Double(currentRating))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Spacer()

                // Big live percentage
                VStack(spacing: 4) {
                    Text("\(Int(rating.rounded()))%")
                        .font(AppTypography.ratingLarge)
                        .foregroundStyle(AppColors.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: Int(rating.rounded()))

                    Text(skillName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                // Premium slider (level label shown below big %)
                PremiumRatingSlider(value: $rating, showLevelLabel: true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .font(AppTypography.body)
                        .lineLimit(3...6)
                        .padding(AppSpacing.xs)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))

                    Text("Record what went well or what you'd like to improve")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.primary)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColors.cardBackground)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Update Mastery")
                        .font(AppTypography.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task { @MainActor in
                            let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
                            let success = await onSave(Int(rating), trimmedNotes.isEmpty ? nil : trimmedNotes)
                            isSaving = false
                            if success { dismiss() }
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

#Preview {
    RateSkillView(skillName: "Serve", currentRating: 75) { _, _ in true }
}
