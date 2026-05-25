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
        .background(AppColors.background)
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
                withAnimation { contentReady = true }
                await vm.loadStats()
            }
        }
    }

    @ViewBuilder
    private func chatContent(_ viewModel: ChatViewModel) -> some View {
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if viewModel.messages.isEmpty {
                            emptyState
                        }

                        ForEach(viewModel.messages) { message in
                            messageRow(message, viewModel: viewModel)
                                .id(message.id)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Spacer()
                            .frame(height: 100)
                    }
                    .padding(.top, AppSpacing.sm)
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
            }

            // Input bar pinned to bottom
            inputBar(viewModel)
        }
        .contentLoadTransition(isLoaded: contentReady)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
                .frame(height: 80)

            CoachMascot(state: .idle, size: 72)

            Text("How can I improve your game today?")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.role {
        case .user:
            userRow(message)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxs)

        case .agent:
            agentRow(message, viewModel: viewModel)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
        }
    }

    // MARK: - User Row

    private func userRow(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 60)

            if case .text(let text) = message.content {
                Text(text)
                    .font(.system(size: 16, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.agentBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    // MARK: - Agent Row

    @ViewBuilder
    private func agentRow(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        if case .text(let text) = message.content {
            // Text messages — clean, no bubble, like Claude
            HStack(alignment: .top, spacing: 12) {
                CoachMascot(state: .talking, size: 28)
                    .padding(.top, 2)

                Text(text)
                    .font(.system(size: 16, design: .rounded))
                    .lineSpacing(5)
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        } else {
            // Non-text content (loading, cards, errors)
            HStack(alignment: .top, spacing: 12) {
                CoachMascot(state: mascotState(for: message), size: 28)
                    .padding(.top, 2)

                agentContent(message, viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Agent Content (non-text types)

    @ViewBuilder
    private func agentContent(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.content {
        case .text:
            EmptyView()

        case .loading:
            HStack(spacing: AppSpacing.xxs) {
                typingIndicator
                Text("Thinking...")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                Button { viewModel.cancelSending() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.4))
                }
                .accessibilityLabel("Cancel analysis")
            }
            .padding(.top, 4)

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

        case .clarification(let preview):
            ClarificationCard(
                preview: preview,
                onSelectOption: { optionId in
                    viewModel.selectClarificationOption(messageId: message.id, optionId: optionId)
                },
                onDismiss: {
                    viewModel.dismissClarification(messageId: message.id)
                }
            )

        case .drillSuggestions(let preview):
            DrillSuggestionsCard(
                preview: preview,
                onAddDrill: { drillIndex in
                    viewModel.addDrillToQueue(messageId: message.id, drillIndex: drillIndex)
                }
            )

        case .error(let errorText):
            let isOffline = errorText.contains("offline") || errorText.contains("connection")
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Label(
                    isOffline ? "No Connection" : "Something went wrong",
                    systemImage: isOffline ? "wifi.slash" : "exclamationmark.triangle.fill"
                )
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.coral)
                Text(errorText)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                Button {
                    viewModel.retrySession(messageId: message.id)
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.vertical, AppSpacing.xxxs)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.coral)
                .accessibilityLabel("Retry sending message")
            }
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        TypingDotsView()
    }

    // MARK: - Mascot State Mapping

    private func mascotState(for message: ChatMessage) -> MascotState {
        switch message.content {
        case .text:
            return .talking
        case .loading:
            return .thinking
        case .sessionPreview(let preview):
            return preview.confirmState == .confirmed ? .celebrating : .talking
        case .skillDeletion, .skillCreation, .drillSuggestions:
            return .talking
        case .clarification:
            return .idle
        case .error:
            return .idle
        }
    }

    // MARK: - Input Bar

    private func inputBar(_ viewModel: ChatViewModel) -> some View {
        let canSend = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSending
            && networkMonitor.isConnected

        return HStack(alignment: .center, spacing: 8) {
            TextField("How can I help you today?", text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ), axis: .vertical)
                .font(.system(size: 16, design: .rounded))
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit {
                    if canSend { viewModel.send() }
                }

            Button {
                viewModel.send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(canSend ? AppColors.primary : AppColors.textSecondary.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.xxs)
    }
}

// MARK: - Typing Dots

private struct TypingDotsView: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppColors.primary.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -3 : 3)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
