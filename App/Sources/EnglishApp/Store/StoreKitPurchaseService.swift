import Foundation
import StoreKit

/// Thin wrapper over StoreKit 2. It translates StoreKit values into the
/// `PurchaseService` types and makes no decisions of its own; every decision
/// lives in `EntitlementStore`, which is tested against a fake.
struct StoreKitPurchaseService: PurchaseService {
    func products(for ids: [String]) async throws -> [StoreProduct] {
        let products = try await Product.products(for: ids)
        return products.map {
            StoreProduct(
                id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice,
                kind: PremiumProducts.kind(forProductID: $0.id)
            )
        }
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
                result.append(StoreEntitlement(productID: transaction.productID, isActive: true))
            }
        }
        return result
    }

    var entitlementUpdates: AsyncStream<StoreEntitlement> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    if case .verified(let transaction) = verification {
                        continuation.yield(
                            StoreEntitlement(productID: transaction.productID, isActive: Self.isActive(transaction))
                        )
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

    /// Revoked (refunded) and expired transactions are not entitlements.
    private static func isActive(_ transaction: Transaction) -> Bool {
        if transaction.revocationDate != nil { return false }
        if let expiration = transaction.expirationDate, expiration <= Date() { return false }
        return true
    }
}
