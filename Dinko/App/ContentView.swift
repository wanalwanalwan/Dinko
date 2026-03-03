import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Image(systemName: "message")
                    Text("Coach")
                }

                NavigationStack {
                    SkillListView()
                }
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Progress")
                }

                NavigationStack {
                    DrillQueueView()
                }
                .tabItem {
                    Image(systemName: "list.clipboard")
                    Text("Drills")
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
