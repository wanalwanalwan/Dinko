import SwiftUI

/// Routes the coach chat UI based on the user's role:
/// - Player: conversation list (all coaches, active + past)
/// - Coach: list of player conversations
struct CoachChatContainerView: View {
    // Seed from cache so returning users never see a spinner.
    // isLoading stays true only when there is no cached role at all.
    @State private var userRole: UserRole?
    @State private var isLoading: Bool

    let realtimeService: RealtimeService

    private let chatService = CoachChatService()

    init(realtimeService: RealtimeService) {
        self.realtimeService = realtimeService
        if let cached = UserDefaults.standard.string(forKey: "pkkl_user_role"),
           let role = UserRole(rawValue: cached) {
            _userRole = State(initialValue: role)
            _isLoading = State(initialValue: false)
        } else {
            _userRole = State(initialValue: nil)
            _isLoading = State(initialValue: true)
        }
    }

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
        // Suppress animation on the loading→content swap so it never
        // bleeds into the parent ZStack's tab-switch transition.
        .animation(.none, value: isLoading)
        .background(AppColors.background)
        .task { await loadUserRole() }
    }

    // MARK: - Load

    private func loadUserRole() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            isLoading = false
            return
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
