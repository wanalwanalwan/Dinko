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
        VStack(spacing: 0) {
            // Quick stats bar
            statsBar(viewModel)

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

            Divider()

            // Input bar
            inputBar(viewModel)
        }
    }

    // MARK: - Stats Bar

    private func statsBar(_ viewModel: ChatViewModel) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Label("\(viewModel.totalSkills) skills", systemImage: "chart.bar.fill")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)

            if let focus = viewModel.weeklyFocusTitle {
                Divider()
                    .frame(height: 14)
                Label(focus, systemImage: "target")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.teal)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppColors.cardBackground)
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

            // Quick prompts
            VStack(spacing: AppSpacing.xxs) {
                quickPrompt("Played doubles for an hour, dinks felt great")
                quickPrompt("Rough session — overheads kept sailing long")
                quickPrompt("Practiced serves for 30 min, getting more consistent")
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    private func quickPrompt(_ text: String) -> some View {
        Button {
            viewModel?.inputText = text
        } label: {
            HStack {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.teal)
                Text(text)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.teal.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppSpacing.lg)
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
        HStack(spacing: AppSpacing.xxs) {
            TextField("How was your session?", text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ), axis: .vertical)
                .font(AppTypography.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, AppSpacing.xxs)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

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
        .padding(.horizontal, AppSpacing.xs)
        .padding(.vertical, AppSpacing.xxs)
    }
}
