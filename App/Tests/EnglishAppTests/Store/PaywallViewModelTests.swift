import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

@MainActor
final class PaywallViewModelTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func makeStore(_ fake: FakePurchaseService) -> EntitlementStore {
        let name = "paywall-tests-\(UUID().uuidString)"
        suiteNames.append(name)
        return EntitlementStore(service: fake, defaults: UserDefaults(suiteName: name)!)
    }

    private let packageMode = PaywallMode.package(
        productID: "com.niinova22.englishapp.package.yds", packageName: "YDS: Academic Vocabulary I"
    )

    func test_load_packageMode_isReadyWithTheSingleProductSelected() async {
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(FakePurchaseService(products: [.yds, .monthly])))
        XCTAssertEqual(vm.state, .loadingProducts)
        await vm.load()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.products, [.yds])
        XCTAssertEqual(vm.selectedProductID, "com.niinova22.englishapp.package.yds")
        XCTAssertEqual(vm.title, "YDS: Academic Vocabulary I")
    }

    func test_load_premiumMode_listsYearlyThenMonthly_andPreselectsYearly() async {
        let vm = PaywallViewModel(mode: .premium, store: makeStore(FakePurchaseService(products: [.yearly, .monthly, .yds])))
        await vm.load()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.products.map(\.id), [PremiumProducts.yearly, PremiumProducts.monthly])
        XCTAssertEqual(vm.selectedProductID, PremiumProducts.yearly)
        XCTAssertEqual(vm.title, "AI Premium")
    }

    func test_load_failure_thenRetrySucceeds() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.productsError = StoreTestError.boom
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        XCTAssertEqual(vm.state, .loadFailed)

        fake.productsError = nil
        await vm.load()
        XCTAssertEqual(vm.state, .ready)
    }

    func test_load_withNoMatchingProducts_isLoadFailed() async {
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(FakePurchaseService(products: [])))
        await vm.load()
        XCTAssertEqual(vm.state, .loadFailed)
    }

    func test_purchase_success_ownsTheProductAndSucceeds() async {
        let store = makeStore(FakePurchaseService(products: [.yds]))
        let vm = PaywallViewModel(mode: packageMode, store: store)
        await vm.load()
        await vm.purchase()
        XCTAssertEqual(vm.state, .succeeded)
        XCTAssertTrue(store.owns("com.niinova22.englishapp.package.yds"))
    }

    func test_purchase_cancelled_returnsToReadyWithoutAMessage() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.success(.cancelled)]
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.purchase()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertNil(vm.notice)
    }

    func test_purchase_pending_showsTheWaitingState() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.success(.pending)]
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.purchase()
        XCTAssertEqual(vm.state, .pending)
    }

    func test_purchase_failure_isRetryable() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.failure(StoreTestError.boom)]
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.purchase()
        XCTAssertEqual(vm.state, .failed("The purchase could not be completed. Try again in a bit."))

        await vm.purchase()   // second attempt uses the default outcome: purchased
        XCTAssertEqual(vm.state, .succeeded)
        XCTAssertEqual(fake.purchaseCallCount, 2)
    }

    func test_purchase_afterSuccess_doesNothing() async {
        let fake = FakePurchaseService(products: [.yds])
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.purchase()
        await vm.purchase()
        XCTAssertEqual(fake.purchaseCallCount, 1)
    }

    func test_dismissError_returnsFailedToReady() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.purchaseOutcomes = [.failure(StoreTestError.boom)]
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.purchase()
        vm.dismissError()
        XCTAssertEqual(vm.state, .ready)
    }

    func test_restore_withNothingToRestore_showsANotice() async {
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(FakePurchaseService(products: [.yds])))
        await vm.load()
        await vm.restore()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.notice, "No purchase to restore was found on this account.")
    }

    func test_restore_findingThePackage_succeeds() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.entitlementsAfterRestore = [StoreEntitlement(productID: "com.niinova22.englishapp.package.yds", isActive: true)]
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.restore()
        XCTAssertEqual(vm.state, .succeeded)
        XCTAssertEqual(fake.restoreCallCount, 1)
    }

    func test_restore_failure_isReported() async {
        let fake = FakePurchaseService(products: [.yds])
        fake.restoreError = StoreTestError.boom
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(fake))
        await vm.load()
        await vm.restore()
        XCTAssertEqual(vm.state, .failed("Purchases could not be restored. Try again in a bit."))
    }

    func test_isAlreadyOwned_reflectsTheStore() async {
        let fake = FakePurchaseService(
            products: [.yds],
            entitlements: [StoreEntitlement(productID: "com.niinova22.englishapp.package.yds", isActive: true)]
        )
        let store = makeStore(fake)
        await store.refresh()
        let vm = PaywallViewModel(mode: packageMode, store: store)
        XCTAssertTrue(vm.isAlreadyOwned)
        let premiumVM = PaywallViewModel(mode: .premium, store: store)
        XCTAssertFalse(premiumVM.isAlreadyOwned)
    }

    // MARK: Trial and pricing texts

    private func priced(_ product: StoreProduct, _ price: String, trial: Bool, eligible: Bool) -> StoreProduct {
        var p = product
        p.price = Decimal(string: price)!
        p.priceFormat = .currency(code: "USD").locale(Locale(identifier: "en_US"))
        p.trialDays = trial ? 7 : nil
        p.isTrialEligible = eligible
        return p
    }

    func test_eligibleLearner_seesTheTrialCTA_timeline_andTerms() async {
        let yearly = priced(.yearly, "39.99", trial: true, eligible: true)
        let monthly = priced(.monthly, "6.99", trial: true, eligible: true)
        let vm = PaywallViewModel(mode: .premium, store: makeStore(FakePurchaseService(products: [yearly, monthly])))
        await vm.load()
        XCTAssertTrue(vm.showsTrialTimeline)
        XCTAssertEqual(vm.ctaTitle, "Try free for 7 days")
        XCTAssertEqual(vm.trialTerms, "Free for 7 days, then ₺399,99 a year. Cancel anytime.")
        XCTAssertEqual(vm.savingsPercent, 52)
        XCTAssertEqual(vm.perMonthText(for: yearly), "≈ $3.33 / month")
        XCTAssertNil(vm.perMonthText(for: monthly))
    }

    func test_learnerWhoUsedTheTrial_seesThePlainPrice() async {
        let yearly = priced(.yearly, "39.99", trial: true, eligible: false)
        let vm = PaywallViewModel(mode: .premium, store: makeStore(FakePurchaseService(products: [yearly])))
        await vm.load()
        XCTAssertFalse(vm.showsTrialTimeline)
        XCTAssertNil(vm.trialTerms)
        XCTAssertEqual(vm.ctaTitle, "Subscribe · ₺399,99")
        XCTAssertNil(vm.savingsPercent, "no monthly price to compare with")
    }

    func test_packageMode_ctaIsAOneTimeBuy() async {
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(FakePurchaseService(products: [.yds])))
        await vm.load()
        XCTAssertEqual(vm.ctaTitle, "Buy · ₺299,99")
        XCTAssertFalse(vm.showsTrialTimeline)
    }
}

final class PackageStatsTests: XCTestCase {
    @MainActor
    func test_countsUnitsLessonsAndQuestions() throws {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        let package = try XCTUnwrap(context.fetch(FetchDescriptor<ContentPackage>()).first)
        XCTAssertEqual(PackageStats(package), PackageStats(units: 2, lessons: 4, questions: 0))
    }
}

