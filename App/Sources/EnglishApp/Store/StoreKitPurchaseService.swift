import Foundation
import StoreKit

/// Thin wrapper over StoreKit 2. It translates StoreKit values into the
/// `PurchaseService` types and makes no decisions of its own; every decision
/// lives in `EntitlementStore`, which is tested against a fake.
struct StoreKitPurchaseService: PurchaseService {
    func products(for ids: [String]) async throws -> [StoreProduct] {
        let products = try await Product.products(for: ids)
        var result: [StoreProduct] = []
        for product in products {
            var item = StoreProduct(
                id: product.id, displayName: product.displayName, displayPrice: product.displayPrice,
                kind: PremiumProducts.kind(forProductID: product.id)
            )
            item.price = product.price
            item.priceFormat = product.priceFormatStyle
            if let subscription = product.subscription, let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial {
                item.trialDays = Self.days(in: offer.period)
                item.isTrialEligible = await subscription.isEligibleForIntroOffer
            }
            result.append(item)
        }
        return result
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreError.productNotFound
        }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw StoreError.unverified }
            // currentEntitlements keeps reporting finished non-consumable and
            // active subscription transactions, so finishing now cannot lose access.
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func currentEntitlements() async -> [StoreEntitlement] {
        var result: [StoreEntitlement] = []
        for await verification in Transaction.currentEntitlements {
            if case .verified(let transaction) = verification, Self.isActive(transaction) {
                result.append(StoreEntitlement(
                    productID: transaction.productID, isActive: true, trialEndsAt: await Self.trialEnd(of: transaction)
                ))
            }
        }
        return result
    }

    var entitlementUpdates: AsyncStream<StoreEntitlement> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    if case .verified(let transaction) = verification {
                        let isActive = Self.isActive(transaction)
                        continuation.yield(StoreEntitlement(
                            productID: transaction.productID, isActive: isActive,
                            trialEndsAt: isActive ? await Self.trialEnd(of: transaction) : nil
                        ))
                        await transaction.finish()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    /// The first charge date of a subscription still in its free trial that
    /// will renew; nil otherwise (a trial the learner cancelled will not charge).
    private static func trialEnd(of transaction: Transaction) async -> Date? {
        let isIntroductory: Bool
        if #available(iOS 17.2, *) {
            isIntroductory = transaction.offer?.type == .introductory
        } else {
            isIntroductory = transaction.offerType == .introductory
        }
        guard isIntroductory, let expiration = transaction.expirationDate else { return nil }
        if let status = await transaction.subscriptionStatus,
           case .verified(let renewal) = status.renewalInfo, !renewal.willAutoRenew {
            return nil
        }
        return expiration
    }

    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }

    /// Revoked (refunded) and expired transactions are not entitlements.
    private static func isActive(_ transaction: Transaction) -> Bool {
        if transaction.revocationDate != nil { return false }
        if let expiration = transaction.expirationDate, expiration <= Date() { return false }
        return true
    }
}
