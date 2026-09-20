import Foundation

/// Inert placeholder replaced by the real StoreKit wrapper in the next task.
struct StoreKitPurchaseService: PurchaseService {
    func products(for ids: [String]) async throws -> [StoreProduct] { [] }
    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func currentEntitlements() async -> [StoreEntitlement] { [] }
    var entitlementUpdates: AsyncStream<StoreEntitlement> { AsyncStream { $0.finish() } }
    func restore() async throws {}
}
