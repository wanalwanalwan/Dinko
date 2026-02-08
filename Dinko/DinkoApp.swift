import SwiftUI

@main
struct DinkoApp: App {
    private let dependencies = DependencyContainer()
    @State private var showPersistenceError = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencies, dependencies)
                .alert("Storage Unavailable", isPresented: $showPersistenceError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your data could not be loaded and won't be saved. Try restarting the app or freeing up storage.")
                }
                .onAppear {
                    if dependencies.persistenceError != nil {
                        showPersistenceError = true
                    }
                }
        }
    }
}
