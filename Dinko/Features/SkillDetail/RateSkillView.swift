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

                Text("\(Int(rating))%")
                    .font(AppTypography.ratingLarge)
                    .foregroundStyle(AppColors.teal)

                VStack(spacing: AppSpacing.xxxs) {
                    HStack {
                        Text("0")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Spacer()
                        Text("100")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Slider(value: $rating, in: 0...100, step: 1)
                        .tint(AppColors.teal)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .font(AppTypography.body)
                        .lineLimit(3...6)
                        .padding(AppSpacing.xs)
                        .background(AppColors.background)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.xs))

                    Text("Record what went well or what you'd like to improve")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.teal)
                }

                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(AppColors.cardBackground)
            .navigationTitle("Rate \(skillName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSaving = true
                        Task {
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
