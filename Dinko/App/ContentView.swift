import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            TabView {
                NavigationStack {
                    ChatView()
                }
                .tabItem {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                    Text("Coach")
                }

                NavigationStack {
                    SkillListView()
                }
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }

                NavigationStack {
                    DrillQueueView()
                }
                .tabItem {
                    Image(systemName: "figure.run")
                    Text("Drills")
                }

                NavigationStack {
                    ArchivedSkillsView()
                }
                .tabItem {
                    Image(systemName: "archivebox")
                    Text("Archived")
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
