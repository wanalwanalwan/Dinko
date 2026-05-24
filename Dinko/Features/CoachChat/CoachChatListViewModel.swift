import Foundation

@Observable
@MainActor
final class CoachChatListViewModel {
    var conversations: [Conversation] = []
    var playerNames: [UUID: String] = [:]
    var isLoading = true
    var error: String?

    private let chatService = CoachChatService()
    private let currentUserId: UUID

    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.coachUnreadCount }
    }

    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }

    func loadConversations() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            error = "Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        do {
            conversations = try await chatService.fetchConversations(
                forUserId: currentUserId,
                role: .coach,
                authToken: token
            )

            // Fetch player names
            for conversation in conversations {
                if playerNames[conversation.playerId] == nil {
                    let name = try await chatService.fetchPartnerName(
                        partnerId: conversation.playerId,
                        authToken: token
                    )
                    playerNames[conversation.playerId] = name
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadConversations()
    }
}
