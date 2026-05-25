import SwiftUI

struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var selectedTab = 0
    @State private var showTypeSelection = false
    @State private var showSessionForm = false
    @State private var selectedSessionType: SessionType = .game
    @State private var homeRefreshID = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(selectedTab: $selectedTab, refreshID: homeRefreshID)
                }
                .tag(0)

                NavigationStack {
                    CoachTabView()
                }
                .tag(1)

                NavigationStack {
                    SkillListView()
                }
                .tag(2)

                NavigationStack {
                    DrillQueueView()
                }
                .tag(3)

                NavigationStack {
                    TimelineView()
                }
                .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)

            if selectedTab == 0 {
                FloatingActionButton {
                    showTypeSelection = true
                }
                .padding(.bottom, AppSpacing.sm)
                .transition(.scale.combined(with: .opacity))
            }
        }
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
        }) {
            let viewModel = LogSessionViewModel(
                skillRepository: dependencies.skillRepository,
                sessionRepository: dependencies.sessionRepository,
                journalEntryRepository: dependencies.journalEntryRepository,
                skillRatingRepository: dependencies.skillRatingRepository,
                drillRepository: dependencies.drillRepository
            )
            LogSessionView(
                viewModel: {
                    viewModel.sessionType = selectedSessionType
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
                .fill(AppColors.separator)
                .frame(height: 0.5)

            HStack {
                tabButton("house", label: "Home", tag: 0)
                tabButton("bubble.left", label: "Coach", tag: 1)
                tabButton("doc.text", label: "Progress", tag: 2)
                tabButton("list.bullet.clipboard", label: "Drills", tag: 3)
                tabButton("book", label: "Timeline", tag: 4)
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(AppColors.background)
    }

    private func tabButton(_ icon: String, label: String, tag: Int) -> some View {
        Button {
            selectedTab = tag
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == tag ? .semibold : .medium))
            }
            .foregroundStyle(selectedTab == tag ? AppColors.primary : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
