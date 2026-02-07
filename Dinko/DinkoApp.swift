import SwiftUI

@main
struct DinkoApp: App {
    private let dependencies = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencies, dependencies)
        }
    }
}
