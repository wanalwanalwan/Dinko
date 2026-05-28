import SwiftUI

struct SkillListView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: SkillListViewModel?
    @State private var showingAddSkill = false
    @State private var contentReady = false
    @State private var ringProgress: CGFloat = 0

    var body: some View {
        Group {
            if let viewModel {
                skillListContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("My Progress")
        .navigationDestination(for: Skill.self) { skill in
            SkillDetailView(skill: skill)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSkill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSkill, onDismiss: {
            if let viewModel {
                Task { await viewModel.loadSkills() }
            }
        }) {
            AddEditSkillView()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.errorMessage != nil },
            set: { if !$0 { viewModel?.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.errorMessage ?? "")
        }
        .task {
            if viewModel == nil {
                let vm = SkillListViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository
                )
                viewModel = vm
                withAnimation { contentReady = true }
                await vm.loadSkills()
            }
        }
        .onAppear {
            if let viewModel {
                Task { await viewModel.loadSkills() }
            }
        }
    }

    @ViewBuilder
    private func skillListContent(_ viewModel: SkillListViewModel) -> some View {
        if viewModel.skills.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    overviewCard(viewModel)
                        .staggeredAppearance(index: 0)

                    // Individual skill cards
                    ForEach(Array(viewModel.skills.enumerated()), id: \.element.id) { index, skill in
                        NavigationLink(value: skill) {
                            SkillCard(
                                skill: skill,
                                subskillCount: viewModel.subskillCounts[skill.id] ?? 0,
                                rating: viewModel.latestRatings[skill.id] ?? 0,
                                delta: viewModel.ratingDeltas[skill.id]
                            )
                        }
                        .buttonStyle(.pressable)
                        .staggeredAppearance(index: index + 1)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xxs)
                .padding(.bottom, AppSpacing.xl)
                .contentLoadTransition(isLoaded: contentReady)
            }
            .background(AppColors.backgroundGradient)
            .refreshable {
                await viewModel.loadSkills()
            }
        }
    }

    // MARK: - Overview Card

    private func overviewCard(_ viewModel: SkillListViewModel) -> some View {
        let ratings = viewModel.skills.map { viewModel.latestRatings[$0.id] ?? 0 }
        let avgRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / ratings.count
        let improvingCount = viewModel.ratingDeltas.values.filter { $0 > 0 }.count
        let targetProgress = CGFloat(avgRating) / 100.0

        let ringSize: CGFloat = 72
        let strokeWidth: CGFloat = 7
        let ringTrackSize = ringSize - 8
        let innerDiscSize = ringSize - strokeWidth * 2 - 10

        return HStack(spacing: AppSpacing.md) {
            // Progress ring (Bevel-style, matching HomeView)
            ZStack {
                // Outer bevel
                Circle()
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: .white.opacity(0.85), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.16), radius: 6, x: 0, y: 3)

                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .padding(2)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)

                // Track
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(hex: "E8F1EB"),
                                Color(hex: "DDE8E1"),
                                Color.white.opacity(0.9),
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringTrackSize, height: ringTrackSize)
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 2, x: -1, y: -1)

                // Progress arc
                if ringProgress > 0 {
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "DFFF00"),
                                    AppColors.successGreenLight,
                                    Color(hex: "38D900"),
                                    AppColors.successGreenDark,
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringTrackSize, height: ringTrackSize)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: AppColors.successGreen.opacity(0.35), radius: 3, x: 0, y: 1)
                }

                // White inner disc
                Circle()
                    .fill(.white)
                    .frame(width: innerDiscSize, height: innerDiscSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: 0.5)
                    )
                    .shadow(color: .white.opacity(0.9), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)

                // Center text
                VStack(spacing: -2) {
                    Text("\(avgRating)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("%")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .onAppear {
                animateRing(to: targetProgress)
            }
            .onChange(of: avgRating) {
                animateRing(to: targetProgress)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("Overall Progress")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(viewModel.skills.count) skills \u{00B7} \(improvingCount) improving")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()
        }
        .heroCard()
    }

    private func animateRing(to target: CGFloat) {
        ringProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 1.2)) {
                ringProgress = target
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Skills Yet")
            } icon: {
                CoachMascot(state: .idle, size: 48, animated: false)
            }
        } description: {
            Text("Add your first skill to start tracking your progress.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundGradient)
    }
}

#Preview {
    NavigationStack {
        SkillListView()
    }
}
