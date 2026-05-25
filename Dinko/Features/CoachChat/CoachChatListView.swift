import SwiftUI

struct CoachChatListView: View {
    @State var viewModel: CoachChatListViewModel
    let realtimeService: RealtimeService

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.conversations.isEmpty {
                emptyState
            } else {
                conversationList
            }
        }
        .background(AppColors.background)
        .navigationTitle("My Players")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadConversations()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink {
                        CoachChatView(
                            viewModel: CoachChatViewModel(
                                conversation: conversation,
                                currentUserId: currentUserId,
                                role: .coach,
                                realtimeService: realtimeService
                            )
                        )
                    } label: {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, AppSpacing.md)
                }
            }
        }
    }

    // MARK: - Row

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: AppSpacing.sm) {
            // Avatar circle
            Circle()
                .fill(AppColors.primary.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(playerInitial(for: conversation.playerId))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(viewModel.playerNames[conversation.playerId] ?? "Player")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    if let lastAt = conversation.lastMessageAt {
                        Text(relativeTime(lastAt))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                HStack {
                    Text(conversation.lastMessagePreview ?? "No messages yet")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    if conversation.coachUnreadCount > 0 {
                        Text("\(conversation.coachUnreadCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.coral)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
            Text("No players assigned")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("You'll see your assigned players here once an admin connects you.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
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

    private func playerInitial(for playerId: UUID) -> String {
        let name = viewModel.playerNames[playerId] ?? "P"
        return String(name.prefix(1)).uppercased()
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
