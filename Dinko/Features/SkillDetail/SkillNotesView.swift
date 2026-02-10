import SwiftUI

struct SkillNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    let skillName: String
    let onSave: (String) async -> Void

    init(skillName: String, notes: String, onSave: @escaping (String) async -> Void) {
        self.skillName = skillName
        self._notes = State(initialValue: notes)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if isEditing {
                    TextField("Add your notes here...", text: $notes, axis: .vertical)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(5...30)
                        .focused($isFocused)
                        .padding(AppSpacing.sm)
                        .background(AppColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                } else {
                    if notes.isEmpty {
                        Text("Tap to add notes...")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                            .onTapGesture {
                                isEditing = true
                                isFocused = true
                            }
                    } else {
                        Text(notes)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.sm)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                            .onTapGesture {
                                isEditing = true
                                isFocused = true
                            }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.top, AppSpacing.xs)
        }
        .background(AppColors.background)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isFocused = false
                        isEditing = false
                        Task {
                            await onSave(notes.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                    }
                    .font(AppTypography.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.teal)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkillNotesView(
            skillName: "Serve",
            notes: "Focus on toss consistency and follow through."
        ) { _ in }
    }
}
