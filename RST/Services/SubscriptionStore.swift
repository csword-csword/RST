import Foundation
import Observation
import StoreKit

/// Manages the Pinpoint annual subscription via StoreKit 2 (Apple In-App
/// Purchase). Apple — not Stripe — must handle subscriptions that unlock in-app
/// digital functionality (App Store Guideline 3.1.1). The physical pin device is
/// sold separately through normal commerce (Stripe/retail) and is not an IAP.
@Observable @MainActor
final class SubscriptionStore {
    /// Create this product in App Store Connect as an auto-renewable subscription.
    static let annualProductID = "fitness.pinpoint.annual"
    static let fallbackPrice = "$49.99"

    private(set) var annualProduct: Product?
    private(set) var isSubscribed = false
    private(set) var isWorking = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    nonisolated init() {}

    /// Begin observing transactions and load product + entitlement state.
    func start() {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(update)
                }
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlements()
        }
    }

    var priceText: String {
        annualProduct?.displayPrice ?? Self.fallbackPrice
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.annualProductID])
            annualProduct = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product = annualProduct else {
            lastError = "Subscription is unavailable right now."
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlements()
                    return isSubscribed
                }
                lastError = "Purchase couldn't be verified."
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.annualProductID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
            await refreshEntitlements()
        }
    }
}
