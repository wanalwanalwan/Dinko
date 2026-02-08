import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                SkillListView()
            }
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Progress")
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
    }
}

#Preview {
    ContentView()
}
