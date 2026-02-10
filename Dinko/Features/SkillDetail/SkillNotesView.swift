import SwiftUI

struct SkillNotesView: View {
    @State private var notes: String
    let onSave: (String) async -> Void

    init(notes: String, onSave: @escaping (String) async -> Void) {
        self._notes = State(initialValue: notes)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            TextField("Add your notes here...", text: $notes, axis: .vertical)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(5...50)
                .padding(AppSpacing.sm)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
        }
        .background(AppColors.background)
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            Task {
                await onSave(notes.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}

#Preview {
    NavigationStack {
        SkillNotesView(
            notes: "Focus on toss consistency and follow through."
        ) { _ in }
    }
}
