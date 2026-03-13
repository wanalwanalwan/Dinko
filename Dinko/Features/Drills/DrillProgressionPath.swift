import SwiftUI

struct DrillProgressionPath: View {
    let drills: [Drill]
    let skillNames: [UUID: String]
    let onComplete: (UUID) async -> Void
    let onSkip: (UUID) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("UP NEXT")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)

            ForEach(Array(drills.enumerated()), id: \.element.id) { index, drill in
                let state: DrillNodeState = index == 0 ? .next : .upcoming

                VStack(spacing: 0) {
                    // Connector line above (skip for first)
                    if index > 0 {
                        connectorLine(isActive: false)
                    }

                    NavigationLink {
                        DrillDetailView(
                            drill: drill,
                            skillName: skillNames[drill.skillId] ?? "Skill",
                            onComplete: { await onComplete(drill.id) },
                            onSkip: { await onSkip(drill.id) }
                        )
                    } label: {
                        DrillNodeView(
                            drill: drill,
                            state: state,
                            skillName: skillNames[drill.skillId]
                        )
                    }
                    .buttonStyle(.pressable)
                }
                .staggeredAppearance(index: index)
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.sm)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private func connectorLine(isActive: Bool) -> some View {
        HStack {
            Rectangle()
                .fill(isActive ? AppColors.teal : AppColors.separator)
                .frame(width: 3, height: 24)
                .clipShape(Capsule())
                .frame(width: 60)

            Spacer()
        }
    }
}

#Preview {
    let skillId = UUID()
    let drills = [
        Drill(skillId: skillId, name: "Cross-Court Dink Rally", durationMinutes: 15),
        Drill(skillId: skillId, name: "Third Shot Drop Practice", durationMinutes: 10),
        Drill(skillId: skillId, name: "Serve & Return Consistency", durationMinutes: 20),
    ]

    NavigationStack {
        ScrollView {
            DrillProgressionPath(
                drills: drills,
                skillNames: [skillId: "Dinking"],
                onComplete: { _ in },
                onSkip: { _ in }
            )
            .padding()
        }
    }
}
