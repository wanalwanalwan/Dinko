import SwiftUI

struct ChatView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ChatViewModel?
    @State private var contentReady = false
    @FocusState private var isInputFocused: Bool
    private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil {
                let vm = ChatViewModel(
                    skillRepository: dependencies.skillRepository,
                    skillRatingRepository: dependencies.skillRatingRepository,
                    drillRepository: dependencies.drillRepository,
                    journalEntryRepository: dependencies.journalEntryRepository
                )
                viewModel = vm
                await vm.loadStats()
                withAnimation { contentReady = true }
            }
        }
    }

    @ViewBuilder
    private func chatContent(_ viewModel: ChatViewModel) -> some View {
        ZStack(alignment: .bottom) {
            // Messages
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                if !networkMonitor.isConnected {
                    HStack(spacing: AppSpacing.xxs) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 12, weight: .semibold))
                        Text("You're offline. Messages will send when reconnected.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, AppSpacing.xxs)
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.coral.opacity(0.9))
                }

                ScrollView {
                    LazyVStack(spacing: AppSpacing.xs) {
                        if viewModel.messages.isEmpty {
                            emptyState
                        }

                        ForEach(viewModel.messages) { message in
                            messageBubble(message, viewModel: viewModel)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                    removal: .opacity
                                ))
                        }

                        // Bottom spacer so content doesn't hide behind floating input
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation(AppAnimations.springSmooth) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                } // VStack
            }

            // Floating input bar
            inputBar(viewModel)
        }
        .contentLoadTransition(isLoaded: contentReady)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.teal.opacity(0.5))

            Text("How was your session?")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Describe your pickleball session and I'll analyze your skills, suggest drills, and update your progress.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
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
                Button { viewModel.cancelSending() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                }
                .accessibilityLabel("Cancel analysis")
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
                },
                onToggleDrill: { index in
                    viewModel.toggleDrill(messageId: message.id, drillIndex: index)
                },
                onToggleSkillUpdate: { index in
                    viewModel.toggleSkillUpdate(messageId: message.id, skillUpdateIndex: index)
                },
                onToggleSubskill: { skillIndex, subIndex in
                    viewModel.toggleSubskillDelta(messageId: message.id, skillUpdateIndex: skillIndex, subskillIndex: subIndex)
                }
            )

        case .skillDeletion(let preview):
            SkillDeletionCard(
                preview: preview,
                onConfirm: {
                    Task { await viewModel.confirmDeletion(messageId: message.id) }
                },
                onCancel: {
                    viewModel.cancelDeletion(messageId: message.id)
                }
            )

        case .skillCreation(let preview):
            SkillCreationCard(
                preview: preview,
                onConfirm: {
                    Task { await viewModel.confirmSkillCreation(messageId: message.id) }
                },
                onCancel: {
                    viewModel.cancelSkillCreation(messageId: message.id)
                },
                onCategoryChanged: { newCategory in
                    viewModel.updateSkillCreationCategory(messageId: message.id, category: newCategory)
                }
            )

        case .error(let errorText):
            let isOffline = errorText.contains("offline") || errorText.contains("connection")
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Label(
                    isOffline ? "No Connection" : "Something went wrong",
                    systemImage: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
                )
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.coral)
                Text(errorText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Button {
                    viewModel.retrySession(messageId: message.id)
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(AppTypography.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xxxs)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.coral)
                .accessibilityLabel("Retry sending message")
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
                    viewModel.send()
                }

            HStack {
                Spacer()

                Button {
                    viewModel.send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending || !networkMonitor.isConnected
                                ? AppColors.textSecondary.opacity(0.3)
                                : AppColors.teal
                        )
                }
                .disabled(
                    viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending || !networkMonitor.isConnected
                )
                .accessibilityLabel("Send message")
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
