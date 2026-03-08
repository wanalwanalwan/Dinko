import SwiftUI

struct ContentView: View {
    @State private var showSplash = true
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HomeView(selectedTab: $selectedTab)
                }
                .tag(0)
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

                NavigationStack {
                    ChatView()
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
                    JournalView()
                }
                .tag(4)
                .tabItem {
                    Image(systemName: "book")
                    Text("Journal")
                }
            }
            .tint(AppColors.teal)

            if showSplash {
                SplashScreenView {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
