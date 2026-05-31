import SwiftUI

/// Routes the coach chat UI based on the user's role:
/// - Player: conversation list (all coaches, active + past)
/// - Coach: list of player conversations
struct CoachChatContainerView: View {
    @State private var userRole: UserRole? = .player
    @State private var isLoading = true

    let realtimeService: RealtimeService

    private let chatService = CoachChatService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch userRole {
                case .coach:
                    CoachChatListView(
                        viewModel: CoachChatListViewModel(currentUserId: currentUserId),
                        realtimeService: realtimeService
                    )
                default:
                    PlayerConversationListView(
                        viewModel: PlayerConversationListViewModel(currentUserId: currentUserId),
                        realtimeService: realtimeService
                    )
                }
            }
        }
        .background(AppColors.background)
        .task { await loadUserRole() }
    }

    // MARK: - Load

    private func loadUserRole() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            isLoading = false
            return
        }

        if let cached = UserDefaults.standard.string(forKey: "pkkl_user_role"),
           let role = UserRole(rawValue: cached) {
            userRole = role
        }

        do {
            if let profile = try await chatService.fetchUserProfile(userId: currentUserId, authToken: token) {
                userRole = profile.role
                UserDefaults.standard.set(profile.role.rawValue, forKey: "pkkl_user_role")
            } else {
                userRole = .player
                UserDefaults.standard.set(UserRole.player.rawValue, forKey: "pkkl_user_role")
            }
        } catch {
            if userRole == nil { userRole = .player }
        }

        isLoading = false
    }

    // MARK: - Helpers

    private var currentUserId: UUID {
        guard let data = UserDefaults.standard.data(forKey: "pkkl_user_json"),
              let user = try? JSONDecoder().decode(AuthService.AuthUser.self, from: data),
              let id = UUID(uuidString: user.id) else {
            return UUID()
        }
        return id
    }
}
