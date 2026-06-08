import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let subscriptionService = SubscriptionService.shared

    @State private var selectedProduct: StoreProduct?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.md) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    }
                }
                .padding(.top, AppSpacing.xxs)

                // Hero icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.highlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, AppSpacing.xxs)

                // Heading
                Text("Unlock Full Training")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Get access to complete multi-week programs and curated training from the pros.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.sm)

                // Feature checklist
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    featureRow("Complete multi-week training programs")
                    featureRow("Curated pro player programs")
                    featureRow("Unlimited AI program generation")
                    featureRow("All future premium features")
                }
                .padding(AppSpacing.sm)
                .neumorphicRaised(cornerRadius: AppSpacing.cornerRadiusMd)

                // Pricing cards
                if subscriptionService.monthlyProduct != nil || subscriptionService.annualProduct != nil {
                    VStack(spacing: AppSpacing.xs) {
                        if let annual = subscriptionService.annualProduct {
                            pricingCard(
                                product: annual,
                                label: "Annual",
                                sublabel: annualMonthlyCost(annual),
                                badge: savingsBadge(annual),
                                isSelected: selectedProduct?.productIdentifier == annual.productIdentifier
                            )
                        }

                        if let monthly = subscriptionService.monthlyProduct {
                            pricingCard(
                                product: monthly,
                                label: "Monthly",
                                sublabel: monthly.localizedPriceString + "/mo",
                                badge: nil,
                                isSelected: selectedProduct?.productIdentifier == monthly.productIdentifier
                            )
                        }
                    }
                } else {
                    ProgressView()
                        .padding()
                }

                // Subscribe button
                if let product = selectedProduct {
                    Button {
                        Task { await purchaseSelected(product) }
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Subscribe")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadiusMd))
                    }
                    .disabled(isPurchasing)
                    .buttonStyle(.pressable)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.coral)
                        .multilineTextAlignment(.center)
                }

                // Restore purchases
                Button {
                    Task { await restore() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.primary)
                }
                .disabled(isPurchasing)

                // Legal links
                Text("Payment will be charged to your Apple ID account. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.sm)

                Spacer().frame(height: AppSpacing.lg)
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .background(AppColors.backgroundGradient.ignoresSafeArea())
        .task {
            await subscriptionService.loadOfferings()
            // Default to annual if available
            selectedProduct = subscriptionService.annualProduct ?? subscriptionService.monthlyProduct
        }
    }

    // MARK: - Components

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.xxs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColors.successGreen)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    private func pricingCard(
        product: StoreProduct,
        label: String,
        sublabel: String,
        badge: String?,
        isSelected: Bool
    ) -> some View {
        Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.textPrimary)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.successGreen)
                                .clipShape(Capsule())
                        }
                    }
                    Text(sublabel)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                Text(product.localizedPriceString)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .padding(AppSpacing.sm)
            .neumorphicTinted(
                color: isSelected ? AppColors.primary : .clear,
                tintOpacity: isSelected ? 0.08 : 0,
                borderOpacity: isSelected ? 0.3 : 0.08,
                cornerRadius: AppSpacing.cornerRadiusMd
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func purchaseSelected(_ product: StoreProduct) async {
        isPurchasing = true
        errorMessage = nil
        do {
            let success = try await subscriptionService.purchase(product)
            if success {
                dismiss()
            }
        } catch {
            errorMessage = "Purchase could not be completed. Please try again."
        }
        isPurchasing = false
    }

    private func restore() async {
        isPurchasing = true
        errorMessage = nil
        do {
            try await subscriptionService.restorePurchases()
            if subscriptionService.isPro {
                dismiss()
            } else {
                errorMessage = "No active subscription found."
            }
        } catch {
            errorMessage = "Could not restore purchases. Please try again."
        }
        isPurchasing = false
    }

    // MARK: - Helpers

    private func annualMonthlyCost(_ annual: StoreProduct) -> String {
        let monthly = annual.price as Decimal / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = annual.priceFormatter?.locale ?? .current
        let formatted = formatter.string(from: monthly as NSDecimalNumber) ?? ""
        return formatted + "/mo"
    }

    private func savingsBadge(_ annual: StoreProduct) -> String? {
        guard let monthly = subscriptionService.monthlyProduct else { return nil }
        let yearlyFromMonthly = monthly.price as Decimal * 12
        guard yearlyFromMonthly > 0 else { return nil }
        let savings = ((yearlyFromMonthly - annual.price as Decimal) / yearlyFromMonthly) * 100
        let pct = NSDecimalNumber(decimal: savings).intValue
        return pct > 0 ? "Save \(pct)%" : nil
    }
}
