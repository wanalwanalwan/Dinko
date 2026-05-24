import SwiftUI

/// Routes the coach chat UI based on the user's role:
/// - Player: single conversation thread (or "no coach assigned" empty state)
/// - Coach: list of player conversations
struct CoachChatContainerView: View {
    @State private var userRole: UserRole? = .player
    @State private var conversation: Conversation?
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
                    playerView
                }
            }
        }
        .background(AppColors.background)
        .task {
            await loadUserContext()
        }
    }

    // MARK: - Player View

    @ViewBuilder
    private var playerView: some View {
        if let conversation {
            CoachChatView(
                viewModel: CoachChatViewModel(
                    conversation: conversation,
                    currentUserId: currentUserId,
                    role: .player,
                    realtimeService: realtimeService
                )
            )
        } else {
            noCoachState
        }
    }

    // MARK: - Empty States

    private var noCoachState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "person.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            Text("No coach assigned")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("You'll be paired with a coach soon. In the meantime, try the AI Coach!")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Load

    private func loadUserContext() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            isLoading = false
            return
        }

        // Check cached role first
        if let cachedRole = UserDefaults.standard.string(forKey: "pkkl_user_role"),
           let role = UserRole(rawValue: cachedRole) {
            userRole = role
        }

        do {
            // Fetch fresh profile — default to player if none exists
            if let profile = try await chatService.fetchUserProfile(userId: currentUserId, authToken: token) {
                userRole = profile.role
                UserDefaults.standard.set(profile.role.rawValue, forKey: "pkkl_user_role")
            } else {
                userRole = .player
                UserDefaults.standard.set(UserRole.player.rawValue, forKey: "pkkl_user_role")
            }

            // If player, fetch their conversation
            if userRole == .player {
                conversation = try await chatService.fetchConversation(playerId: currentUserId, authToken: token)
            }
        } catch {
            // Default to player on error if no cached role
            if userRole == nil {
                userRole = .player
            }
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
