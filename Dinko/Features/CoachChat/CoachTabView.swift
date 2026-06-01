import SwiftUI

/// Coach tab — Grok-style segmented layout with "AI Agent" and "My Coach" tabs.
struct CoachTabView: View {
    @Binding var selectedTab: Int
    @State private var selectedSegment: Int = 0
    @State private var realtimeService = RealtimeService()
    @State private var showCoachDirectory = false
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
        .sheet(isPresented: $showCoachDirectory) {
            CoachDirectoryView(
                currentUserId: currentUserId,
                realtimeService: realtimeService
            )
        }
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

            // Right action: new AI chat on segment 0, find a coach on segment 1
            Button {
                if selectedSegment == 1 {
                    showCoachDirectory = true
                }
            } label: {
                Image(systemName: selectedSegment == 1 ? "person.badge.plus" : "square.and.pencil")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(selectedSegment == 1 ? AppColors.primary : AppColors.textPrimary)
                    .animation(.easeInOut(duration: 0.18), value: selectedSegment)
            }
            .accessibilityLabel(selectedSegment == 1 ? "Find a Coach" : "New Chat")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Helpers

    private var currentUserId: UUID {
        guard let data = UserDefaults.standard.data(forKey: "pkkl_user_json"),
              let user = try? JSONDecoder().decode(AuthService.AuthUser.self, from: data),
              let id = UUID(uuidString: user.id) else { return UUID() }
        return id
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
