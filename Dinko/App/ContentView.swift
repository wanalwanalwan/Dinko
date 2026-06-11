import SwiftUI

struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var selectedTab = 0
    @State private var showTypeSelection = false
    @State private var showSessionForm = false
    @State private var selectedSessionType: SessionType = .game
    @State private var selectedSessionDate: Date = Date()
    @State private var homeRefreshID = UUID()
    @State private var isQuickLog = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Today
            NavigationStack {
                TodayView()
            }
            .tag(0)

            // Tab 1: Journey
            NavigationStack {
                JourneyView()
            }
            .tag(1)

            // Tab 2: Coach
            NavigationStack {
                CoachTabView(selectedTab: $selectedTab)
            }
            .tag(2)

            // Tab 3: Profile (promoted from sheet to full tab)
            ProfileView()
            .tag(3)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            customTabBar
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .sheet(isPresented: $showTypeSelection) {
            SessionTypeSheet { type in
                selectedSessionType = type
                showTypeSelection = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSessionForm = true
                }
            }
        }
        .sheet(isPresented: $showSessionForm, onDismiss: {
            homeRefreshID = UUID()
            isQuickLog = false
        }) {
            let viewModel = LogSessionViewModel(
                skillRepository: dependencies.skillRepository,
                sessionRepository: dependencies.sessionRepository,
                journalEntryRepository: dependencies.journalEntryRepository,
                skillRatingRepository: dependencies.skillRatingRepository,
                drillRepository: dependencies.drillRepository,
                confidenceEntryRepository: dependencies.confidenceEntryRepository
            )
            LogSessionView(
                viewModel: {
                    viewModel.sessionType = selectedSessionType
                    viewModel.sessionDate = selectedSessionDate
                    viewModel.isQuickMode = isQuickLog
                    return viewModel
                }(),
                selectedTab: $selectedTab
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.separator.opacity(0.5))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                tabButton(icon: "house", filledIcon: "house.fill", label: "Today", tag: 0)
                tabButton(icon: "map", filledIcon: "map.fill", label: "Journey", tag: 1)
                tabButton(icon: "bubble.left", filledIcon: "bubble.left.fill", label: "Coach", tag: 2)
                tabButton(icon: "person.circle", filledIcon: "person.circle.fill", label: "Profile", tag: 3)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .background(.ultraThinMaterial)
    }

    private func tabButton(icon: String, filledIcon: String, label: String, tag: Int) -> some View {
        let isActive = selectedTab == tag

        return Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isActive {
                        Capsule()
                            .fill(AppColors.primary.opacity(0.12))
                            .frame(width: 52, height: 28)
                    }

                    Image(systemName: isActive ? filledIcon : icon)
                        .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                        .symbolRenderingMode(.monochrome)
                }
                .frame(height: 28)

                Text(label)
                    .font(.system(size: 10, weight: isActive ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isActive ? AppColors.primary : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
