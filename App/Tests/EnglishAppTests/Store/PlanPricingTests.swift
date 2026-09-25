import XCTest
@testable import EnglishApp

final class PlanPricingTests: XCTestCase {
    func test_savingsPercent_roundsToNearest_andIsNilWithoutASaving() {
        XCTAssertEqual(PlanPricing.savingsPercent(monthly: Decimal(string: "6.99")!, yearly: Decimal(string: "39.99")!), 52)
        XCTAssertEqual(PlanPricing.savingsPercent(monthly: Decimal(string: "149.99")!, yearly: Decimal(string: "899.99")!), 50)
        XCTAssertNil(PlanPricing.savingsPercent(monthly: 10, yearly: 120))
        XCTAssertNil(PlanPricing.savingsPercent(monthly: 0, yearly: 10))
    }

    func test_perMonth_dividesTheYearlyPrice() {
        XCTAssertEqual(PlanPricing.perMonth(yearly: 36), 3)
    }

    func test_showsTrial_onlyWithAnOfferTheLearnerCanStillUse() {
        let base = StoreProduct(id: PremiumProducts.yearly, displayName: "Y", displayPrice: "$39.99", kind: .premiumYearly)
        var eligible = base
        eligible.trialDays = 7
        eligible.isTrialEligible = true
        XCTAssertTrue(PlanPricing.showsTrial(eligible))

        var used = eligible
        used.isTrialEligible = false
        XCTAssertFalse(PlanPricing.showsTrial(used))
        XCTAssertFalse(PlanPricing.showsTrial(base), "no introductory offer")
    }
}

@MainActor
final class TrialEntitlementTests: XCTestCase {
    func makeStore(_ fake: FakePurchaseService) -> EntitlementStore {
        EntitlementStore(service: fake, defaults: UserDefaults(suiteName: "trial-\(UUID().uuidString)")!)
    }

    func test_activeIntroOffer_exposesItsEndDate_andClearsWhenInactive() async {
        let end = Date(timeIntervalSince1970: 2_000_000_000)
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.yearly, isActive: true, trialEndsAt: end)])
        let store = makeStore(fake)
        await store.refresh()
        XCTAssertEqual(store.trialEndsAt, end)

        store.apply(StoreEntitlement(productID: PremiumProducts.yearly, isActive: false))
        XCTAssertNil(store.trialEndsAt)
    }

    func test_paidSubscription_hasNoTrialEndDate() async {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.monthly, isActive: true)])
        let store = makeStore(fake)
        await store.refresh()
        XCTAssertNil(store.trialEndsAt)
    }
}
