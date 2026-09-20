import Foundation
@testable import EnglishApp

/// Scriptable stand-in for StoreKit. A `.purchased` outcome also adds an
/// active entitlement, mirroring what StoreKit's `currentEntitlements` does.
final class FakePurchaseService: PurchaseService, @unchecked Sendable {
    var products: [StoreProduct]
    var entitlements: [StoreEntitlement]
    /// Consumed front to back; when empty the next purchase is `.purchased`.
    var purchaseOutcomes: [Result<PurchaseOutcome, Error>] = []
    var productsError: Error?
    var restoreError: Error?
    /// If set, replaces `entitlements` when `restore()` runs.
    var entitlementsAfterRestore: [StoreEntitlement]?
    private(set) var purchaseCallCount = 0
    private(set) var restoreCallCount = 0

    let entitlementUpdates: AsyncStream<StoreEntitlement>
    private let updatesContinuation: AsyncStream<StoreEntitlement>.Continuation

    init(products: [StoreProduct] = [], entitlements: [StoreEntitlement] = []) {
        self.products = products
        self.entitlements = entitlements
        var captured: AsyncStream<StoreEntitlement>.Continuation!
        self.entitlementUpdates = AsyncStream { captured = $0 }
        self.updatesContinuation = captured
    }

    func emit(_ update: StoreEntitlement) {
        updatesContinuation.yield(update)
    }

    func products(for ids: [String]) async throws -> [StoreProduct] {
        if let productsError { throw productsError }
        return products.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseCallCount += 1
        let next: Result<PurchaseOutcome, Error> = purchaseOutcomes.isEmpty
            ? .success(.purchased) : purchaseOutcomes.removeFirst()
        switch next {
        case .failure(let error):
            throw error
        case .success(let outcome):
            if outcome == .purchased {
                entitlements.removeAll { $0.productID == productID }
                entitlements.append(StoreEntitlement(productID: productID, isActive: true))
            }
            return outcome
        }
    }

    func currentEntitlements() async -> [StoreEntitlement] {
        entitlements
    }

    func restore() async throws {
        restoreCallCount += 1
        if let restoreError { throw restoreError }
        if let entitlementsAfterRestore { entitlements = entitlementsAfterRestore }
    }
}

extension StoreProduct {
    static let yds = StoreProduct(
        id: "com.niinova22.englishapp.package.yds", displayName: "YDS Paketi",
        displayPrice: "₺299,99", kind: .package
    )
    static let monthly = StoreProduct(
        id: PremiumProducts.monthly, displayName: "AI Premium (aylık)",
        displayPrice: "₺49,99", kind: .premiumMonthly
    )
    static let yearly = StoreProduct(
        id: PremiumProducts.yearly, displayName: "AI Premium (yıllık)",
        displayPrice: "₺399,99", kind: .premiumYearly
    )
}

enum StoreTestError: Error, Equatable { case boom }
