import XCTest
@testable import EnglishApp

@MainActor
final class EntitlementStoreTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "store-tests-\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    private let ydsID = "com.niinova22.englishapp.package.yds"

    func test_refresh_grantsActiveEntitlementsAndIgnoresInactive() async {
        let fake = FakePurchaseService(entitlements: [
            StoreEntitlement(productID: ydsID, isActive: true),
            StoreEntitlement(productID: PremiumProducts.monthly, isActive: false),
        ])
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        await store.refresh()
        XCTAssertEqual(store.activeProductIDs, [ydsID])
        XCTAssertTrue(store.owns(ydsID))
        XCTAssertFalse(store.isPremium)
    }

    func test_packageAndPremiumAreIndependent() async {
        let premiumOnly = EntitlementStore(
            service: FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.yearly, isActive: true)]),
            defaults: makeDefaults()
        )
        await premiumOnly.refresh()
        XCTAssertTrue(premiumOnly.isPremium)
        XCTAssertFalse(premiumOnly.owns(ydsID))

        let packageOnly = EntitlementStore(
            service: FakePurchaseService(entitlements: [StoreEntitlement(productID: ydsID, isActive: true)]),
            defaults: makeDefaults()
        )
        await packageOnly.refresh()
        XCTAssertTrue(packageOnly.owns(ydsID))
        XCTAssertFalse(packageOnly.isPremium)
    }

    func test_apply_revocationRemovesTheProduct() async {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.monthly, isActive: true)])
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        await store.refresh()
        XCTAssertTrue(store.isPremium)

        store.apply(StoreEntitlement(productID: PremiumProducts.monthly, isActive: false))
        XCTAssertFalse(store.isPremium)
        XCTAssertEqual(store.activeProductIDs, [])
    }

    func test_purchase_purchased_grantsAccess() async throws {
        let fake = FakePurchaseService(products: [.yds])
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        await store.refresh()
        XCTAssertFalse(store.owns(ydsID))

        let outcome = try await store.purchase(productID: ydsID)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(store.owns(ydsID))
        XCTAssertEqual(fake.purchaseCallCount, 1)
    }

    func test_purchase_cancelledAndPending_doNotGrant() async throws {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.success(.cancelled), .success(.pending)]
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        let cancelled = try await store.purchase(productID: ydsID)
        XCTAssertEqual(cancelled, .cancelled)
        XCTAssertFalse(store.owns(ydsID))
        let pending = try await store.purchase(productID: ydsID)
        XCTAssertEqual(pending, .pending)
        XCTAssertFalse(store.owns(ydsID))
    }

    func test_purchase_failure_throwsAndDoesNotGrant() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.failure(StoreTestError.boom)]
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        do {
            _ = try await store.purchase(productID: ydsID)
            XCTFail("expected the purchase to throw")
        } catch {
            XCTAssertEqual(error as? StoreTestError, .boom)
        }
        XCTAssertFalse(store.owns(ydsID))
    }

    func test_restore_refreshesFromTheService() async throws {
        let fake = FakePurchaseService()
        fake.entitlementsAfterRestore = [StoreEntitlement(productID: ydsID, isActive: true)]
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        await store.refresh()
        XCTAssertFalse(store.owns(ydsID))

        try await store.restore()
        XCTAssertEqual(fake.restoreCallCount, 1)
        XCTAssertTrue(store.owns(ydsID))
    }

    func test_cache_survivesARestartUntilALiveReadReplacesIt() async {
        let defaults = makeDefaults()
        let first = EntitlementStore(
            service: FakePurchaseService(entitlements: [StoreEntitlement(productID: ydsID, isActive: true)]),
            defaults: defaults
        )
        await first.refresh()

        // Offline cold start: nothing has been read from StoreKit yet.
        let second = EntitlementStore(service: FakePurchaseService(), defaults: defaults)
        XCTAssertTrue(second.owns(ydsID), "the cached entitlement must survive the restart")
        XCTAssertEqual(second.snapshot.activeProductIDs, [ydsID])

        // A live read that returns nothing (e.g. a refund) replaces the cache.
        await second.refresh()
        XCTAssertFalse(second.owns(ydsID))
        XCTAssertEqual(second.snapshot.activeProductIDs, [])
    }

    func test_change_callsOnChangeOnlyWhenTheSetChanges() async {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: ydsID, isActive: true)])
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        var calls = 0
        store.onChange = { calls += 1 }

        await store.refresh()
        XCTAssertEqual(calls, 1)
        await store.refresh()
        XCTAssertEqual(calls, 1, "an unchanged set must not notify")
        store.apply(StoreEntitlement(productID: ydsID, isActive: false))
        XCTAssertEqual(calls, 2)
    }

    func test_snapshotMirrorsTheActiveSet() async {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.yearly, isActive: true)])
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        await store.refresh()
        XCTAssertEqual(store.snapshot.activeProductIDs, [PremiumProducts.yearly])
    }

    func test_start_appliesLiveUpdates() async throws {
        let fake = FakePurchaseService()
        let store = EntitlementStore(service: fake, defaults: makeDefaults())
        let task = Task { await store.start() }

        fake.emit(StoreEntitlement(productID: ydsID, isActive: true))
        for _ in 0..<100 where !store.owns(ydsID) {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(store.owns(ydsID))

        fake.emit(StoreEntitlement(productID: ydsID, isActive: false))
        for _ in 0..<100 where store.owns(ydsID) {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertFalse(store.owns(ydsID))
        task.cancel()
    }
}
