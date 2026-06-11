import SwiftUI

/// Celebration type determining the overlay content.
enum CelebrationType {
    case skillAtTarget(skillName: String)
    case pillarComplete(pillarName: String)
    case goalReached(dupr: String)

    var title: String {
        switch self {
        case .skillAtTarget(let name): return "\(name) at Target!"
        case .pillarComplete(let name): return "\(name) Complete!"
        case .goalReached(let dupr): return "Goal Reached: \(dupr)!"
        }
    }

    var subtitle: String {
        switch self {
        case .skillAtTarget: return "Your confidence has reached the benchmark."
        case .pillarComplete: return "Every skill in this pillar is at target."
        case .goalReached: return "You've reached all your targets. Time for a new goal!"
        }
    }

    var iconName: String {
        switch self {
        case .skillAtTarget: return "checkmark.seal.fill"
        case .pillarComplete: return "star.fill"
        case .goalReached: return "trophy.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .skillAtTarget: return AppColors.successGreen
        case .pillarComplete: return AppColors.tierGold
        case .goalReached: return AppColors.trophyGold
        }
    }
}

/// Full-screen celebration overlay for major milestones.
struct CelebrationOverlay: View {
    let celebration: CelebrationType
    var onDismiss: () -> Void = {}

    @State private var showContent = false

    var body: some View {
        ZStack {
            AppColors.overlayScrim.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: AppSpacing.md) {
                Image(systemName: celebration.iconName)
                    .font(.system(size: 60))
                    .foregroundStyle(celebration.iconColor)
                    .scaleEffect(showContent ? 1.0 : 0.3)

                Text(celebration.title)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.textPrimary)

                Text(celebration.subtitle)
                    .font(AppTypography.cardBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(AppTypography.buttonLabel)
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.xl)
            .neumorphicRaised(intensity: .prominent)
            .padding(.horizontal, AppSpacing.lg)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}
