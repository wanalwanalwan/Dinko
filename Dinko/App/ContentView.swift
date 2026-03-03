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
                    Image(systemName: "bubble.left")
                    Text("Coach")
                }

                NavigationStack {
                    SkillListView()
                }
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Progress")
                }

                NavigationStack {
                    DrillQueueView()
                }
                .tabItem {
                    Image(systemName: "text.alignleft")
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
