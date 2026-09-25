import Foundation
import Observation

/// Single source of truth for what the learner has bought. UI observes
/// `activeProductIDs`; synchronous providers read `snapshot`.
@MainActor
@Observable
final class EntitlementStore {
    static let cacheKey = "store.activeProductIDs"

    private(set) var activeProductIDs: Set<String>
    /// End of a running free trial (see `StoreEntitlement.trialEndsAt`).
    var trialEndsAt: Date? { trialEnds.values.max() }
    private var trialEnds: [String: Date] = [:]

    @ObservationIgnored let snapshot: EntitlementSnapshot
    /// Called after every change of the active set (AppState bumps `dataGeneration`).
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let service: any PurchaseService
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var isStarted = false

    /// Restores the last known active set from `defaults`, so an offline cold
    /// start does not re-lock a purchased package. The first live read in
    /// `start()`/`refresh()` always replaces it.
    init(service: any PurchaseService, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        let cached = Set(defaults.stringArray(forKey: Self.cacheKey) ?? [])
        self.activeProductIDs = cached
        self.snapshot = EntitlementSnapshot(activeProductIDs: cached)
    }

    var isPremium: Bool {
        !activeProductIDs.isDisjoint(with: PremiumProducts.all)
    }

    func owns(_ productID: String) -> Bool {
        activeProductIDs.contains(productID)
    }

    /// Reads the current entitlements once, then applies every update until
    /// the calling task is cancelled. Call from a long-lived `Task`.
    func start() async {
        guard !isStarted else { return }
        isStarted = true
        await refresh()
        for await update in service.entitlementUpdates {
            apply(update)
        }
    }

    func refresh() async {
        let entitlements = await service.currentEntitlements().filter(\.isActive)
        trialEnds = Dictionary(entitlements.compactMap { e in e.trialEndsAt.map { (e.productID, $0) } }, uniquingKeysWith: max)
        setActive(Set(entitlements.map(\.productID)))
    }

    func apply(_ update: StoreEntitlement) {
        trialEnds[update.productID] = update.isActive ? update.trialEndsAt : nil
        var next = activeProductIDs
        if update.isActive {
            next.insert(update.productID)
        } else {
            next.remove(update.productID)
        }
        setActive(next)
    }

    func products(for ids: [String]) async throws -> [StoreProduct] {
        try await service.products(for: ids)
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let outcome = try await service.purchase(productID: productID)
        if outcome == .purchased {
            await refresh()
        }
        return outcome
    }

    func restore() async throws {
        try await service.restore()
        await refresh()
    }

    private func setActive(_ ids: Set<String>) {
        guard ids != activeProductIDs else { return }
        activeProductIDs = ids
        snapshot.replaceActiveProductIDs(ids)
        defaults.set(ids.sorted(), forKey: Self.cacheKey)
        onChange?()
    }
}
