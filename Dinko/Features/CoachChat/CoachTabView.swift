import SwiftUI

/// Coach tab — Grok-style segmented layout with "AI Agent" and "My Coach" tabs.
struct CoachTabView: View {
    @Binding var selectedTab: Int
    @State private var selectedSegment: Int = 0
    @State private var realtimeService = RealtimeService()
    @Namespace private var segmentAnimation

    private let switchAnimation = Animation.spring(response: 0.38, dampingFraction: 0.82)

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ZStack {
                if selectedSegment == 0 {
                    ChatView(selectedTab: $selectedTab)
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    CoachChatContainerView(realtimeService: realtimeService)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .animation(switchAnimation, value: selectedSegment)
        }
        .background(AppColors.background)
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
            withAnimation(switchAnimation) {
                selectedSegment = index
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(AppColors.cardBackground)
                            .matchedGeometryEffect(id: "pill", in: segmentAnimation)
                    }
                }
                .animation(.none, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
