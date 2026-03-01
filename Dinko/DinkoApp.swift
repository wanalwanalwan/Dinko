import SwiftUI

@main
struct DinkoApp: App {
    private let dependencies = DependencyContainer()
    @State private var authViewModel = AuthViewModel()
    @State private var showPersistenceError = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    if hasCompletedOnboarding {
                        ContentView()
                    } else {
                        OnboardingView {
                            hasCompletedOnboarding = true
                        }
                    }
                } else {
                    AuthView(viewModel: authViewModel)
                }
            }
            .environment(\.dependencies, dependencies)
            .environment(\.authViewModel, authViewModel)
            .alert("Storage Unavailable", isPresented: $showPersistenceError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your data could not be loaded and won't be saved. Try restarting the app or freeing up storage.")
            }
            .task {
                if dependencies.persistenceError != nil {
                    showPersistenceError = true
                }
                await authViewModel.restoreSession()
            }
        }
    }
}

// MARK: - Environment Key for AuthViewModel

private struct AuthViewModelKey: EnvironmentKey {
    static let defaultValue: AuthViewModel? = nil
}

extension EnvironmentValues {
    var authViewModel: AuthViewModel? {
        get { self[AuthViewModelKey.self] }
        set { self[AuthViewModelKey.self] = newValue }
    }
}
