import SwiftUI

/// Segmented control wrapper: "AI Coach" vs "My Coach" (human)
/// Coaches skip the segment and go straight to their conversation list.
struct CoachTabView: View {
    @State private var selectedSegment: CoachSegment = .ai
    @State private var userRole: UserRole?
    @State private var realtimeService = RealtimeService()

    enum CoachSegment: String, CaseIterable {
        case ai = "AI Coach"
        case human = "My Coach"
    }

    var body: some View {
        Group {
            if let role = userRole, role == .coach {
                // Coaches go straight to their player list
                CoachChatContainerView(realtimeService: realtimeService)
            } else {
                VStack(spacing: 0) {
                    Picker("Coach", selection: $selectedSegment) {
                        ForEach(CoachSegment.allCases, id: \.self) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)

                    switch selectedSegment {
                    case .ai:
                        ChatView()
                    case .human:
                        CoachChatContainerView(realtimeService: realtimeService)
                    }
                }
            }
        }
        .task {
            // Load cached role
            if let cachedRole = UserDefaults.standard.string(forKey: "pkkl_user_role"),
               let role = UserRole(rawValue: cachedRole) {
                userRole = role
            }

            // Connect realtime
            if let token = await AuthService.shared.validAccessToken() {
                realtimeService.connect(authToken: token)
            }
        }
        .onDisappear {
            realtimeService.disconnect()
        }
    }
}
