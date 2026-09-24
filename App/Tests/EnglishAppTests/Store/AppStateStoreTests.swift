import XCTest
import SwiftData
import LearningEngine
@testable import EnglishApp

@MainActor
final class AppStateStoreTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "appstate-store-tests-\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    private func makeContext(packages: [ContentPackage]) throws -> ModelContext {
        let container = try ModelContainer(
            for: AppModelContainer.schema,
            configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        packages.forEach { context.insert($0) }
        try context.save()
        return context
    }

    private func package(id: String, productID: String?) -> ContentPackage {
        ContentPackage(id: id, name: "Paket \(id)", goal: .yds, levelLower: "B2", levelUpper: "C1", storeProductID: productID)
    }

    func test_ownedProduct_makesItsPackageOwned_andOthersStayPreview() async throws {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: "prod.a", isActive: true)])
        let state = AppState(service: fake, defaults: makeDefaults())
        state.registerPackageProducts(from: try makeContext(packages: [
            package(id: "a", productID: "prod.a"),
            package(id: "b", productID: "prod.b"),
            package(id: "c", productID: nil),
        ]))
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "a"), .preview, "before the first read")

        await state.entitlements.refresh()

        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "a"), .owned)
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "b"), .preview)
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "c"), .preview)
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "unknown"), .preview)
    }

    func test_premiumProductUnlocksPremiumButNotPackages() async throws {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.monthly, isActive: true)])
        let state = AppState(service: fake, defaults: makeDefaults())
        state.registerPackageProducts(from: try makeContext(packages: [package(id: "a", productID: "prod.a")]))
        XCTAssertFalse(state.premiumProvider.isPremium)

        await state.entitlements.refresh()

        XCTAssertTrue(state.premiumProvider.isPremium)
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "a"), .preview)
    }

    func test_entitlementChange_bumpsDataGeneration() async {
        let fake = FakePurchaseService(entitlements: [StoreEntitlement(productID: PremiumProducts.yearly, isActive: true)])
        let state = AppState(service: fake, defaults: makeDefaults())
        XCTAssertEqual(state.dataGeneration, 0)
        await state.entitlements.refresh()
        XCTAssertEqual(state.dataGeneration, 1)
    }

    func test_tutorAccess_resolve() {
        XCTAssertEqual(TutorAccess.resolve(isTutorAvailable: false, isPremium: true), .unavailable)
        XCTAssertEqual(TutorAccess.resolve(isTutorAvailable: false, isPremium: false), .unavailable)
        XCTAssertEqual(TutorAccess.resolve(isTutorAvailable: true, isPremium: false), .needsPremium)
        XCTAssertEqual(TutorAccess.resolve(isTutorAvailable: true, isPremium: true), .allowed)
    }

    #if DEBUG
    func test_developerOverride_unlocksEverything() async throws {
        let defaults = makeDefaults()
        let state = AppState(service: FakePurchaseService(), defaults: defaults)
        state.registerPackageProducts(from: try makeContext(packages: [package(id: "a", productID: "prod.a")]))
        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "a"), .preview)
        XCTAssertFalse(state.premiumProvider.isPremium)

        defaults.set(true, forKey: DeveloperOverride.unlockAllKey)

        XCTAssertEqual(state.accessProvider.accessLevel(forPackageID: "a"), .owned)
        XCTAssertTrue(state.premiumProvider.isPremium)
    }
    #endif
}
