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
            NavigationStack {
                HomeView(selectedTab: $selectedTab, showSessionTypeSheet: $showTypeSelection, selectedSessionDate: $selectedSessionDate, onQuickLog: {
                            isQuickLog = true
                            selectedSessionType = .game
                            selectedSessionDate = Date()
                            showSessionForm = true
                        }, refreshID: homeRefreshID)
            }
            .tag(0)

            NavigationStack {
                CoachTabView(selectedTab: $selectedTab)
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
                drillRepository: dependencies.drillRepository
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
                tabButton(icon: "house", filledIcon: "house.fill", label: "Home", tag: 0)
                tabButton(icon: "bubble.left", filledIcon: "bubble.left.fill", label: "Coach", tag: 1)
                tabButton(icon: "doc.text", filledIcon: "doc.text.fill", label: "Progress", tag: 2)
                tabButton(icon: "list.bullet.clipboard", filledIcon: "list.bullet.clipboard.fill", label: "Drills", tag: 3)
                tabButton(icon: "book", filledIcon: "book.fill", label: "Sessions", tag: 4)
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
