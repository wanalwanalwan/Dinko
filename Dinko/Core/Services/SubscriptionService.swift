import Foundation

// TODO: Re-enable RevenueCat integration later
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    private(set) var isPro: Bool = true // Stubbed: unlock everything for testing
    private(set) var isLoading: Bool = false

    private init() {}

    func configure() {}
    func refreshStatus() async {}
}
