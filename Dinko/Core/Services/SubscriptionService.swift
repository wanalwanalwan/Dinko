import Foundation
import RevenueCat

@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    private(set) var isPro: Bool = false
    private(set) var isLoading: Bool = false
    private(set) var monthlyProduct: StoreProduct?
    private(set) var annualProduct: StoreProduct?

    private init() {}

    func configure() {
        Purchases.configure(withAPIKey: "REVENUECAT_API_KEY_PLACEHOLDER")
    }

    func refreshStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            isPro = customerInfo.entitlements["pro"]?.isActive == true
        } catch {
            // Keep current state on failure
        }
    }

    func loadOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else { return }
            monthlyProduct = current.monthly?.storeProduct
            annualProduct = current.annual?.storeProduct
        } catch {
            // Products unavailable
        }
    }

    func purchase(_ product: StoreProduct) async throws -> Bool {
        let result = try await Purchases.shared.purchase(product: product)
        let isActive = result.customerInfo.entitlements["pro"]?.isActive == true
        isPro = isActive
        return isActive
    }

    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        isPro = customerInfo.entitlements["pro"]?.isActive == true
    }
}
