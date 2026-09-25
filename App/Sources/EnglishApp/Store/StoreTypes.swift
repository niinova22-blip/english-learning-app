import Foundation

struct StoreProduct: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case package, premiumMonthly, premiumYearly }

    let id: String
    let displayName: String
    let displayPrice: String
    let kind: Kind
    /// Numeric price, for savings and per-month texts.
    var price: Decimal = 0
    /// Length of the free introductory offer; nil when there is none.
    var trialDays: Int? = nil
    /// StoreKit allows one introductory offer per subscription group.
    var isTrialEligible: Bool = false
    /// Formats other amounts in the product's currency.
    var priceFormat: Decimal.FormatStyle.Currency? = nil
}

enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    case pending
    case cancelled
}

struct StoreEntitlement: Equatable, Sendable {
    let productID: String
    /// False after revocation, refund or expiry.
    let isActive: Bool
    /// When the free trial of this subscription ends and the first charge
    /// happens; nil for paid periods, packages, or when auto-renew is off.
    var trialEndsAt: Date? = nil
}

enum StoreError: Error, Equatable {
    case productNotFound
    case unverified
}

/// The two AI Premium subscriptions (one subscription group, `ai_premium`).
/// Package product ids are content data (`ContentPackage.storeProductID`).
enum PremiumProducts {
    static let monthly = "com.niinova22.englishapp.premium.monthly"
    static let yearly = "com.niinova22.englishapp.premium.yearly"
    static let all: [String] = [monthly, yearly]

    static func kind(forProductID id: String) -> StoreProduct.Kind {
        switch id {
        case monthly: return .premiumMonthly
        case yearly: return .premiumYearly
        default: return .package
        }
    }
}

/// Everything StoreKit does, behind a protocol so the entitlement logic is
/// testable with a fake. The live implementation must contain no decisions.
protocol PurchaseService: Sendable {
    func products(for ids: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    /// Every currently active entitlement, verified transactions only.
    func currentEntitlements() async -> [StoreEntitlement]
    /// Entitlement changes that do not come from `purchase` (Ask to Buy
    /// approval, renewal, refund, purchases made on another device).
    var entitlementUpdates: AsyncStream<StoreEntitlement> { get }
    func restore() async throws
}
