import SwiftUI

/// Coach tab — players get the AI chat, coaches get their conversation list.
struct CoachTabView: View {
    @Binding var selectedTab: Int
    @State private var userRole: UserRole?
    @State private var realtimeService = RealtimeService()

    var body: some View {
        Group {
            if let role = userRole, role == .coach {
                CoachChatContainerView(realtimeService: realtimeService)
            } else {
                ChatView(selectedTab: $selectedTab)
            }
        }
        .task {
            if let cachedRole = UserDefaults.standard.string(forKey: "pkkl_user_role"),
               let role = UserRole(rawValue: cachedRole) {
                userRole = role
            }

            if let token = await AuthService.shared.validAccessToken() {
                realtimeService.connect(authToken: token)
            }
        }
        .onDisappear {
            realtimeService.disconnect()
        }
    }
}
