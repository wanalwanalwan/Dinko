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
                withAnimation { contentReady = true }
                await vm.loadStats()
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
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
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

            CoachMascot(state: .idle, size: 88)

            Text("How was your session?")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary)

            Text("Describe your pickleball session and I'll analyze your skills, suggest drills, and update your progress.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Message Bubbles

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: UIScreen.main.bounds.width * 0.3)
                userBubbleContent(message)
            }

        case .agent:
            agentMessageRow(message, viewModel: viewModel)
        }
    }

    // MARK: - Agent Message Row

    @ViewBuilder
    private func agentMessageRow(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        if case .text(let text) = message.content {
            // Split long text into conversational chunks
            let chunks = splitIntoChunks(text)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(Array(chunks.enumerated()), id: \.offset) { index, chunk in
                    HStack(alignment: .top, spacing: 8) {
                        if index == 0 {
                            CoachMascot(state: .talking, size: 28)
                        } else {
                            Spacer().frame(width: 28)
                        }

                        Text(chunk)
                            .font(AppTypography.body)
                            .lineSpacing(4)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(14)
                            .frame(maxWidth: 270, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(Color(hex: "F4F6F8"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Spacer()
                    }
                }
            }
        } else {
            // Non-text content (loading, session preview, cards, errors)
            HStack(alignment: .top, spacing: 8) {
                CoachMascot(state: mascotState(for: message), size: 28)
                    .padding(.top, 12) // align with content inside padded bubble
                agentBubbleContent(message, viewModel: viewModel)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - User Bubble

    private func userBubbleContent(_ message: ChatMessage) -> some View {
        Group {
            if case .text(let text) = message.content {
                Text(text)
                    .font(AppTypography.body)
                    .lineSpacing(4)
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(AppColors.teal)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    // MARK: - Agent Bubble Content (non-text types)

    @ViewBuilder
    private func agentBubbleContent(_ message: ChatMessage, viewModel: ChatViewModel) -> some View {
        switch message.content {
        case .text:
            EmptyView() // Handled by agentMessageRow

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
            .padding(14)
            .background(Color(hex: "F4F6F8"))
            .clipShape(RoundedRectangle(cornerRadius: 16))

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
            .padding(14)
            .background(AppColors.coral.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Text Splitting

    /// Splits a long AI message into conversational chunks (1 sentence each).
    private func splitIntoChunks(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [trimmed] }

        // Split into sentences
        var sentences: [String] = []
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { substring, _, _, _ in
            if let s = substring {
                let cleaned = s.trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    sentences.append(cleaned)
                }
            }
        }

        // Only split if there are multiple sentences
        guard sentences.count > 1 else { return [trimmed] }

        return sentences
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
        case .skillDeletion, .skillCreation:
            return .talking
        case .error:
            return .idle
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
