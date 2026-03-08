import SwiftUI

struct DrillQueueView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: DrillQueueViewModel?
    @State private var expandedDrillId: UUID?
    @State private var historyExpanded = false

    var body: some View {
        Group {
            if let viewModel {
                drillContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Practice Queue")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel == nil {
                let vm = DrillQueueViewModel(
                    drillRepository: dependencies.drillRepository,
                    skillRepository: dependencies.skillRepository
                )
                viewModel = vm
                await vm.loadDrills()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadDrills() }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func drillContent(_ viewModel: DrillQueueViewModel) -> some View {
        if viewModel.pendingDrills.isEmpty && viewModel.completedDrills.isEmpty {
            ContentUnavailableView(
                "No Drills Yet",
                systemImage: "figure.run",
                description: Text("Log a session with the Coach to get personalized drill recommendations.")
            )
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.xs) {
                    if !viewModel.pendingDrills.isEmpty {
                        sessionSummaryCard(viewModel)

                        ForEach(viewModel.pendingDrills) { drill in
                            drillCard(drill, viewModel: viewModel)
                        }
                    }

                    if !viewModel.completedDrills.isEmpty {
                        historyCard(viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xl)
            }
            .refreshable {
                await viewModel.loadDrills()
            }
        }
    }

    // MARK: - Session Summary Card

    private func sessionSummaryCard(_ viewModel: DrillQueueViewModel) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "figure.run")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(AppColors.teal)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(viewModel.pendingDrills.count) Drill\(viewModel.pendingDrills.count == 1 ? "" : "s") Queued")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("~\(viewModel.totalEstimatedMinutes) minutes total practice")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Drill Card

    private func drillCard(_ drill: Drill, viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedDrillId = expandedDrillId == drill.id ? nil : drill.id
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        Image(systemName: "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(AppColors.separator)

                        Text(drill.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer()

                        Image(systemName: expandedDrillId == drill.id ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let focusText = drillFocusLabel(drill, viewModel: viewModel) {
                        Text(focusText)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                            .padding(.leading, 34)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        Label("\(drill.durationMinutes) min", systemImage: "timer")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)

                        if let skillName = viewModel.skillNames[drill.skillId] {
                            skillPillBadge(formatDisplayText(skillName))
                        }
                    }
                    .padding(.leading, 34)
                }
            }
            .buttonStyle(.plain)

            if expandedDrillId == drill.id {
                expandedDrillContent(drill, viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.sm)
        .frame(minHeight: 44)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(drill.name), \(drill.durationMinutes) minutes")
        .accessibilityHint(expandedDrillId == drill.id ? "Tap to collapse" : "Tap to expand details")
    }

    // MARK: - Expanded Drill Content

    private func expandedDrillContent(_ drill: Drill, viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Divider()
                .padding(.top, AppSpacing.xs)

            if !drill.drillDescription.isEmpty {
                expandedSection("INSTRUCTIONS", content: drill.drillDescription)
            }

            if !drill.reason.isEmpty {
                expandedSection("WHY THIS DRILL", content: drill.reason)
            }

            if let subskill = drill.targetSubskill, !subskill.isEmpty {
                expandedSection("FOCUS", content: formatDisplayText(subskill))
            }

            if !drill.equipment.isEmpty || drill.playerCount > 1 {
                HStack(spacing: AppSpacing.xs) {
                    if !drill.equipment.isEmpty {
                        Label(drill.equipment, systemImage: "wrench.and.screwdriver")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if drill.playerCount > 1 {
                        Label("\(drill.playerCount) players", systemImage: "person.2")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }

            HStack(spacing: AppSpacing.xs) {
                Button {
                    Task { await viewModel.markDone(drill.id) }
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.successGreen)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.successGreen)

                Button {
                    Task { await viewModel.skip(drill.id) }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, AppSpacing.xxxs)
        }
        .padding(.leading, 34)
        .padding(.top, AppSpacing.xxxs)
    }

    private func expandedSection(_ label: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textSecondary)
                .tracking(0.5)

            Text(content)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(AppColors.textPrimary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Skill Pill Badge

    private func skillPillBadge(_ name: String) -> some View {
        let color = skillPillColor(name)
        return Text(name)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func skillPillColor(_ name: String) -> Color {
        let lower = name.lowercased()
        if lower.contains("drive") || lower.contains("attack") { return Color(hex: "4A6CF7") }
        if lower.contains("dink") || lower.contains("drop") || lower.contains("touch") { return .purple }
        if lower.contains("return") || lower.contains("serve") { return AppColors.successGreen }
        if lower.contains("counter") { return .orange }
        if lower.contains("strategy") || lower.contains("position") { return Color(hex: "8B5CF6") }
        if lower.contains("movement") || lower.contains("footwork") { return AppColors.coral }
        return AppColors.teal
    }

    // MARK: - Display Text Helpers

    private func drillFocusLabel(_ drill: Drill, viewModel: DrillQueueViewModel) -> String? {
        if let subskill = drill.targetSubskill, !subskill.isEmpty {
            return formatDisplayText(subskill) + " practice"
        }
        if let skillName = viewModel.skillNames[drill.skillId] {
            return formatDisplayText(skillName) + " practice"
        }
        return nil
    }

    private func formatDisplayText(_ text: String) -> String {
        let lower = text.lowercased()

        let markers = ["called ", "named "]
        for marker in markers {
            if let range = lower.range(of: marker) {
                let after = String(text[range.upperBound...])
                let extracted = after.prefix(while: { $0 != "," && $0 != "." && $0 != "!" })
                let trimmed = extracted.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { return trimmed }
            }
        }

        let conversationalWords = ["can you", "was working", "working on", "create new",
                                   "super beginner", "beginner level", "i want", "please"]
        let isConversational = conversationalWords.contains(where: { lower.contains($0) })

        if isConversational {
            let firstClause = text.split(separator: ",").first
                .map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? text

            let stopWords: Set<String> = ["can", "you", "create", "new", "skill", "called",
                                          "was", "working", "on", "that", "today", "super",
                                          "i", "please", "want", "to", "a", "my"]
            let cleaned = firstClause.split(separator: " ")
                .filter { !stopWords.contains($0.lowercased()) }
                .joined(separator: " ")

            return cleaned.isEmpty ? text : cleaned
        }

        return text
    }

    // MARK: - History Card

    private func historyCard(_ viewModel: DrillQueueViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    historyExpanded.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.teal)

                    Text("History")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Text("\(viewModel.completedDrills.count)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppColors.textSecondary.opacity(0.1))
                        .clipShape(Capsule())

                    Image(systemName: historyExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)

            if historyExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.completedDrills) { drill in
                        historyDrillRow(drill)
                    }
                }
                .padding(.top, AppSpacing.xxs)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 1)
    }

    private func historyDrillRow(_ drill: Drill) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: drill.status == .completed ? "checkmark.circle.fill" : "forward.fill")
                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(drill.name)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                Text(drill.updatedAt, style: .date)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text(drill.status == .completed ? "Done" : "Skipped")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((drill.status == .completed ? AppColors.successGreen : AppColors.textSecondary).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, AppSpacing.xxs)
        .frame(minHeight: 44)
    }
}

#Preview {
    NavigationStack {
        DrillQueueView()
    }
}
