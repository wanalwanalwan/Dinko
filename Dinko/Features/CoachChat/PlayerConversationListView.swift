import SwiftUI

struct PlayerConversationListView: View {
    @State var viewModel: PlayerConversationListViewModel
    let realtimeService: RealtimeService

    @State private var showDirectory = false
    @State private var showActiveAlert = false

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if viewModel.hasActiveConversation {
                        showActiveAlert = true
                    } else {
                        showDirectory = true
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .alert("Active Conversation", isPresented: $showActiveAlert) {
            Button("OK") {}
        } message: {
            Text("Close your current conversation before starting a new one.")
        }
        .sheet(isPresented: $showDirectory, onDismiss: {
            Task { await viewModel.load() }
        }) {
            CoachDirectoryView(
                currentUserId: viewModel.currentUserId,
                realtimeService: realtimeService
            )
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "person.wave.2")
                .font(.system(size: 52))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
            Text("No coaches yet")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
            Text("Browse coaches and start a conversation.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Find a Coach") { showDirectory = true }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
                .padding(.top, AppSpacing.xxs)
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Conversation List

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xs) {
                if let active = viewModel.activeConversation {
                    activeConversationCard(active)
                }

                if !viewModel.pastConversations.isEmpty {
                    sectionHeader("Past Conversations")
                    ForEach(viewModel.pastConversations) { conversation in
                        pastConversationRow(conversation)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
    }

    // MARK: - Active Card

    private func activeConversationCard(_ conversation: Conversation) -> some View {
        NavigationLink {
            CoachChatView(
                viewModel: CoachChatViewModel(
                    conversation: conversation,
                    currentUserId: viewModel.currentUserId,
                    role: .player,
                    realtimeService: realtimeService
                )
            )
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Label("Active", systemImage: "circle.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                        .labelStyle(.titleAndIcon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(AppColors.successGreen, AppColors.primary)

                    Spacer()

                    if conversation.playerUnreadCount > 0 {
                        Text("\(conversation.playerUnreadCount)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(AppColors.coral)
                            .clipShape(Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                HStack(spacing: AppSpacing.sm) {
                    coachAvatar(for: conversation.coachId, size: 50)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(viewModel.coachNames[conversation.coachId] ?? "Coach")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)

                        if let preview = conversation.lastMessagePreview {
                            Text(preview)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(2)
                        } else {
                            Text("No messages yet — say hi!")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                        }
                    }

                    Spacer()
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primary.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.closeConversation(conversation) }
            } label: {
                Label("Close Conversation", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Past Row

    private func pastConversationRow(_ conversation: Conversation) -> some View {
        NavigationLink {
            CoachChatView(
                viewModel: CoachChatViewModel(
                    conversation: conversation,
                    currentUserId: viewModel.currentUserId,
                    role: .player,
                    realtimeService: realtimeService
                )
            )
        } label: {
            HStack(spacing: AppSpacing.sm) {
                coachAvatar(for: conversation.coachId, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(viewModel.coachNames[conversation.coachId] ?? "Coach")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        Spacer()
                        if let lastAt = conversation.lastMessageAt {
                            Text(relativeTime(lastAt))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }

                    Text(conversation.lastMessagePreview ?? "No messages")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.xs)
            .padding(.horizontal, AppSpacing.xxs)
    }

    private func coachAvatar(for coachId: UUID, size: CGFloat) -> some View {
        let name = viewModel.coachNames[coachId] ?? "C"
        return Circle()
            .fill(AppColors.primary.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.primary)
            )
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
