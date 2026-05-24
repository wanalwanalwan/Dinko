import SwiftUI

struct CoachChatView: View {
    @State var viewModel: CoachChatViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = viewModel.error, viewModel.messages.isEmpty {
                errorState(error)
            } else {
                messageList
                inputBar
            }
        }
        .background(AppColors.background)
        .navigationTitle(viewModel.partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInitial()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if viewModel.hasMoreMessages {
                        Button("Load earlier messages") {
                            Task { await viewModel.loadMoreMessages() }
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.teal)
                        .padding(.top, AppSpacing.sm)
                    }

                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        VStack(spacing: 2) {
                            if shouldShowDateSeparator(at: index) {
                                DateSeparatorView(date: message.createdAt)
                            }

                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }

                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, AppSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { isInputFocused = false }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        let canSend = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isSending

        return HStack(alignment: .bottom, spacing: 8) {
            TextField("Message...", text: $viewModel.inputText, axis: .vertical)
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
                    .background(canSend ? AppColors.teal : AppColors.textSecondary.opacity(0.2))
                    .clipShape(Circle())
            }
            .disabled(!canSend)
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

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.coral)
            Text(message)
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

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = viewModel.messages[index].createdAt
        let previous = viewModel.messages[index - 1].createdAt
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }
}
