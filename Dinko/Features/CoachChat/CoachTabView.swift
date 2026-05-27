import SwiftUI

/// Coach tab — Grok-style segmented layout with "AI Agent" and "My Coach" tabs.
struct CoachTabView: View {
    @Binding var selectedTab: Int
    @State private var selectedSegment: Int = 0
    @State private var realtimeService = RealtimeService()

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                if selectedSegment == 0 {
                    ChatView(selectedTab: $selectedTab)
                } else {
                    CoachChatContainerView(realtimeService: realtimeService)
                }
            }
        }
        .background(Color.white)
        .task {
            if let token = await AuthService.shared.validAccessToken() {
                realtimeService.connect(authToken: token)
            }
        }
        .onDisappear {
            realtimeService.disconnect()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                // Hamburger menu placeholder
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .accessibilityLabel("Menu")

            Spacer()

            segmentedPicker

            Spacer()

            Button {
                // New chat placeholder
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .accessibilityLabel("New Chat")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            segmentButton("AI Agent", index: 0)
            segmentButton("My Coach", index: 1)
        }
        .padding(3)
        .background(AppColors.separator.opacity(0.5))
        .clipShape(Capsule())
    }

    private func segmentButton(_ title: String, index: Int) -> some View {
        let isSelected = selectedSegment == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSegment = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(isSelected ? AppColors.cardBackground : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
