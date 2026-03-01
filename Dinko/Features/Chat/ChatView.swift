import SwiftUI

struct ChatView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authViewModel) private var authViewModel
    @State private var viewModel: ChatViewModel?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("DinkIt")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        Task { await authViewModel?.signOut() }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "person.circle")
                        .foregroundStyle(AppColors.teal)
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = ChatViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository
                )
                vm.authToken = authViewModel?.accessToken ?? ""
                viewModel = vm
                await vm.loadStats()
            }
        }
    }

    @ViewBuilder
    private func chatContent(_ viewModel: ChatViewModel) -> some View {
        ZStack(alignment: .bottom) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        if viewModel.messages.isEmpty {
                            emptyState
                        }

                        ForEach(viewModel.messages) { message in
                            messageBubble(message, viewModel: viewModel)
                                .id(message.id)
                        }

                        // Bottom spacer so content doesn't hide behind floating input
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Floating input bar
            inputBar(viewModel)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        GeometryReader { geo in
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "figure.pickleball")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.teal.opacity(0.4))

                Text("How can I help you?")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .offset(y: geo.size.height * 0.3)
        }
    }

    // MARK: - Message Bubbles

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                userBubbleContent(message)
            }

        case .agent:
            HStack {
                agentBubbleContent(message, viewModel: viewModel)
                Spacer(minLength: 40)
            }
        }
    }

    private func userBubbleContent(_ message: ChatMessage) -> some View {
        Group {
            if case .text(let text) = message.content {
                Text(text)
                    .font(AppTypography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
            }
        }
    }

    @ViewBuilder
    private func agentBubbleContent(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.content {
        case .text(let text):
            Text(text)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))

        case .loading:
            HStack(spacing: AppSpacing.xxs) {
                ProgressView()
                Text("Analyzing your session...")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))

        case .sessionPreview(let preview):
            SessionPreviewCard(
                preview: preview,
                onConfirm: {
                    Task { await viewModel.confirmSession(messageId: message.id) }
                },
                onRetry: {
                    viewModel.retrySession(messageId: message.id)
                }
            )

        case .error(let errorText):
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Label("Something went wrong", systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.coral)
                Text(errorText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Button("Retry") {
                    viewModel.retrySession(messageId: message.id)
                }
                .font(AppTypography.callout)
                .tint(AppColors.coral)
            }
            .padding(AppSpacing.xs)
            .background(AppColors.coral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.sm))
        }
    }

    // MARK: - Input Bar

    private func inputBar(_ viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            TextField("How was your session?", text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ), axis: .vertical)
                .font(AppTypography.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxs)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

            HStack {
                Spacer()

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
                                ? AppColors.textSecondary.opacity(0.3)
                                : AppColors.teal
                        )
                }
                .disabled(
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
                )
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xs)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: -2)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xxs)
    }
}
