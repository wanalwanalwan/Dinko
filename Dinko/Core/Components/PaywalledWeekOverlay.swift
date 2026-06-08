import SwiftUI

struct PaywalledWeekOverlay: ViewModifier {
    var isPaywalled: Bool
    @Binding var showPaywall: Bool

    func body(content: Content) -> some View {
        if isPaywalled {
            content
                .blur(radius: 2.5)
                .opacity(0.7)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                        ProBadge(fontSize: 9)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showPaywall = true
                }
        } else {
            content
        }
    }
}

extension View {
    func paywallOverlay(isPaywalled: Bool, showPaywall: Binding<Bool>) -> some View {
        modifier(PaywalledWeekOverlay(isPaywalled: isPaywalled, showPaywall: showPaywall))
    }
}
