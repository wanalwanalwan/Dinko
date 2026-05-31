import Foundation

@Observable
@MainActor
final class PlayerConversationListViewModel {
    var conversations: [Conversation] = []
    var coachNames: [UUID: String] = [:]
    var isLoading = true
    var error: String?

    private let chatService = CoachChatService()
    let currentUserId: UUID

    var activeConversation: Conversation? {
        conversations.first { $0.status == .active }
    }

    var hasActiveConversation: Bool { activeConversation != nil }

    var pastConversations: [Conversation] {
        conversations.filter { $0.status == .closed }
    }

    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }

    func load() async {
        guard let token = await AuthService.shared.validAccessToken() else {
            error = "Please sign in again."
            isLoading = false
            return
        }

        isLoading = true
        do {
            conversations = try await chatService.fetchConversations(forUserId: currentUserId, role: .player, authToken: token)
            for conversation in conversations where coachNames[conversation.coachId] == nil {
                let name = try await chatService.fetchPartnerName(partnerId: conversation.coachId, authToken: token)
                coachNames[conversation.coachId] = name
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func closeConversation(_ conversation: Conversation) async {
        guard let token = await AuthService.shared.validAccessToken() else { return }
        do {
            try await chatService.closeConversation(id: conversation.id, authToken: token)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async { await load() }
}
