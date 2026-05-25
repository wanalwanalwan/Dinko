import SwiftUI

struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var selectedTab = 0
    @State private var showTypeSelection = false
    @State private var showSessionForm = false
    @State private var selectedSessionType: SessionType = .game
    @State private var homeRefreshID = UUID()

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColors.background)
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage.hairlineSeparator(color: UIColor(AppColors.separator))

        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor(AppColors.textSecondary)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: UIColor(AppColors.primary)
        ]

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = normalAttributes
        itemAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        itemAppearance.selected.titleTextAttributes = selectedAttributes
        itemAppearance.selected.iconColor = UIColor(AppColors.primary)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(selectedTab: $selectedTab, refreshID: homeRefreshID)
                }
                .tag(0)
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("Home")
                }

                NavigationStack {
                    CoachTabView()
                }
                .tag(1)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "bubble.left.fill" : "bubble.left")
                    Text("Coach")
                }

                NavigationStack {
                    SkillListView()
                }
                .tag(2)
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "doc.text.fill" : "doc.text")
                    Text("Progress")
                }

                NavigationStack {
                    DrillQueueView()
                }
                .tag(3)
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
                    Text("Drills")
                }

                NavigationStack {
                    TimelineView()
                }
                .tag(4)
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "book.fill" : "book")
                    Text("Timeline")
                }
            }
            .tint(AppColors.primary)

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

// MARK: - Hairline Separator Image

private extension UIImage {
    static func hairlineSeparator(color: UIColor) -> UIImage {
        let pixel = 1.0 / UIScreen.main.scale
        let size = CGSize(width: 1, height: pixel)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    ContentView()
}
