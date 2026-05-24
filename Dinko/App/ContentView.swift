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
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

                NavigationStack {
                    CoachTabView()
                }
                .tag(1)
                .tabItem {
                    Image(systemName: "bubble.left")
                    Text("Coach")
                }

                NavigationStack {
                    SkillListView()
                }
                .tag(2)
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Progress")
                }

                NavigationStack {
                    DrillQueueView()
                }
                .tag(3)
                .tabItem {
                    Image(systemName: "list.bullet.clipboard")
                    Text("Drills")
                }

                NavigationStack {
                    TimelineView()
                }
                .tag(4)
                .tabItem {
                    Image(systemName: "book")
                    Text("Timeline")
                }
            }
            .tint(AppColors.teal)

            if selectedTab == 0 {
                FloatingActionButton {
                    showTypeSelection = true
                }
                .padding(.bottom, 60)
                .transition(.scale.combined(with: .opacity))
            }
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
}

#Preview {
    ContentView()
}
