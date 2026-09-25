import Foundation

/// Debug-only mode used by the screenshot UI tests (App/UITests): a fresh
/// in-memory store, cleared settings and a demo store with priced products
/// and an eligible free trial, so every screen can be captured without an
/// App Store account. Compiled out of Release builds.
enum ScreenshotMode {
    static var isOn: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-UITestScreenshots")
        #else
        false
        #endif
    }

    static var forcesDark: Bool {
        isOn && ProcessInfo.processInfo.arguments.contains("-UITestDark")
    }

    /// Clears everything this app stored in UserDefaults (reminder, teaser, caches).
    static func resetSettings() {
        guard isOn, let id = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: id)
    }
}

#if DEBUG
/// Store stand-in for screenshots: real-looking prices in the UI language,
/// a 7-day trial the learner can still start, nothing purchased.
struct DemoPurchaseService: PurchaseService {
    func products(for ids: [String]) async throws -> [StoreProduct] {
        let turkish = AppLanguage.current == .turkish
        let code = turkish ? "TRY" : "USD"
        let format = Decimal.FormatStyle.Currency(code: code).locale(AppLanguage.current.locale)
        func product(_ id: String, _ name: String, _ usd: String, _ tryPrice: String, _ kind: StoreProduct.Kind, trial: Bool) -> StoreProduct {
            let price = Decimal(string: turkish ? tryPrice : usd)!
            var item = StoreProduct(id: id, displayName: name, displayPrice: price.formatted(format), kind: kind)
            item.price = price
            item.priceFormat = format
            item.trialDays = trial ? 7 : nil
            item.isTrialEligible = trial
            return item
        }
        let all = [
            product(PremiumProducts.yearly, "AI Premium", "39.99", "899.99", .premiumYearly, trial: true),
            product(PremiumProducts.monthly, "AI Premium", "6.99", "149.99", .premiumMonthly, trial: true),
            product("com.niinova22.englishapp.package.yds", "YDS", "12.99", "349.99", .package, trial: false),
            product("com.niinova22.englishapp.package.business", "Business English", "9.99", "249.99", .package, trial: false),
            product("com.niinova22.englishapp.package.everyday", "Everyday English", "9.99", "249.99", .package, trial: false),
        ]
        return all.filter { ids.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func currentEntitlements() async -> [StoreEntitlement] { [] }
    var entitlementUpdates: AsyncStream<StoreEntitlement> { AsyncStream { _ in } }
    func restore() async throws {}
}
#endif
