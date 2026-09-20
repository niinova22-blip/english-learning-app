# StoreKit 2 Purchases, Entitlements and Paywall (Slice 8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the development access provider with StoreKit 2: a one-time YDS package purchase, an independent AI Premium subscription, a paywall, and the AI gate — with every piece of decision logic tested against a fake purchase service.

**Architecture:** A `PurchaseService` protocol hides StoreKit. `EntitlementStore` (main-actor, observable) is the single source of truth for active product ids and mirrors them into a lock-protected `EntitlementSnapshot`, which the existing synchronous `PackageAccessProvider` reads. The package → product mapping is content data (`ContentPackage.storeProductID`). The paywall is a state machine (`PaywallViewModel`) over the store; screens only gain entry points.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, StoreKit 2 (iOS 17), XcodeGen project, Python 3.12 content assembly, GitHub Actions macOS runners (`Swift Tests`, `App Build`) for all verification.

**Spec:** `docs/superpowers/specs/2026-09-20-storekit-purchases-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification is: commit, push, then confirm **both** CI workflows green — `Swift Tests` (`.github/workflows/swift-tests.yml`, `scripts/ci-test.sh`) and `App Build` (`.github/workflows/app-build.yml`, `scripts/ci-app-build.sh`). CI round trips are slow (App Build ≈ 11 min), so each task writes its test and implementation together and is verified by one push; there is no separate local "red" run.
- **Pushed commits are never amended.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with a blank line and then** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Use single-quoted heredocs; avoid backticks and `$(...)` inside double-quoted bash strings (Git Bash on Windows).
- **Run the assembly script with the real Python interpreter:** `"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py`. Never bare `python`/`python3` (Microsoft Store alias silently swallows file writes). After every run, confirm with `git status --short` that the two derived JSON files really changed.
- **Never hand-edit derived JSON:** `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`.
- **Product ids are contractual and exact:** `com.niinova22.englishapp.package.yds`, `com.niinova22.englishapp.premium.monthly`, `com.niinova22.englishapp.premium.yearly`. Subscription group name `ai_premium`.
- **No prices in code.** The app shows `Product.displayPrice`. (The `.storekit` file's sample prices are local-testing values only.)
- **iOS 17, Swift 5.10, no third-party dependencies.** StoreKit 2 only. Use `@Observable`, not `ObservableObject`.
- **Release must compile.** CI's unsigned build and the TestFlight archive compile the Release configuration; everything debug-only is wrapped in `#if DEBUG` *including every reference* to it. The unit tests run in Debug.
- **All learner-facing Turkish is real Turkish** (`ı İ ş ğ ü ö ç`, never ASCII substitutes), informal "sen" register, UTF-8, LF.
- **Tests assert concrete values** (write the number/string, never a derived expression).
- **Existing tests must stay untouched** unless a task says otherwise: `FixedAccessProvider` (in `TodayPlanCoordinatorTests.swift`) keeps conforming to `PackageAccessProvider`.

---

## File Structure

New, under `App/Sources/EnglishApp/Store/`:

| File | Responsibility |
|---|---|
| `StoreTypes.swift` | `StoreProduct`, `PurchaseOutcome`, `StoreEntitlement`, `StoreError`, `PremiumProducts`, `PurchaseService` protocol |
| `EntitlementSnapshot.swift` | `PackageProduct` and the lock-protected `EntitlementSnapshot` (active ids + package→product table) |
| `EntitlementStore.swift` | The `@MainActor @Observable` source of truth (start/refresh/apply/purchase/restore, cache, snapshot mirror, `onChange`) |
| `StoreAccessProviders.swift` | `PremiumAccessProvider`, `StoreKitPackageAccessProvider`, `SnapshotPremiumAccessProvider`, DEBUG developer overrides |
| `TutorAccess.swift` | `TutorAccess` decision enum + `AppState.tutorAccess` |
| `StoreKitPurchaseService.swift` | Live, logic-free StoreKit wrapper |
| `PaywallViewModel.swift` | `PaywallMode`, `PaywallViewModel` state machine |
| `PaywallView.swift`, `StoreLinks.swift` | Paywall UI and legal URLs |
| `LockedLessonPrompt.swift` | `LockedLesson`, `PaywallTarget`, the locked-lesson sheet + presenter modifier |

Modified: `LearningEngine/.../ContentPackage.swift`, `ContentDocuments.swift`, `ContentImporter.swift`; `scripts/assemble-content.py`; `App/.../AppState.swift`, `EnglishAppApp.swift`, `Access/PackageAccessProvider.swift`, `Tutor/TutorTabView.swift`, `Study/StudySessionView.swift`, `Practice/PracticeSessionView.swift`, `CoursePath/CoursePathView.swift`, `Today/TodayPlanView.swift`, `Profile/ProfileView.swift`, and the derived JSON files.

New tests under `App/Tests/EnglishAppTests/Store/`: `FakePurchaseService.swift` (shared test double), `EntitlementStoreTests.swift`, `AppStateStoreTests.swift`, `PaywallViewModelTests.swift`. New docs: `docs/store-setup.md`, `App/StoreKit/Products.storekit`.

## Spec amendments discovered while planning (already applied to the spec)

- StoreKit does **not** emit in-app purchases on `Transaction.updates`; after `.purchased` the store re-reads `currentEntitlements()`. `Transaction.updates` carries Ask-to-Buy approvals, renewals, refunds and purchases made elsewhere.
- `PackageAccessProvider` is synchronous and not main-actor, so providers read an `EntitlementSnapshot` instead of the main-actor store.

## Task order

Tasks 1-2 are content plumbing (engine, then data). Tasks 3-4 are the entitlement core plus wiring. Task 5 is the live StoreKit wrapper. Tasks 6-9 are paywall and screens. Task 10 is the whole-branch gate. Each task ends CI-green before the next starts.

---

### Task 1: `storeProductID` in the content model and importer

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentDocuments.swift`
- Modify: `LearningEngine/Sources/LearningEngine/Import/ContentImporter.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`

**Interfaces:**
- Produces: `ContentPackage.storeProductID: String?` (default `nil`), `ContentPackage.init(..., skillWeights:, storeProductID: String? = nil)`, `ContentPackageDocument.storeProductID: String?`, `ContentImportError.invalidStoreProductID` (no payload).

- [ ] **Step 1: Model — add the attribute and init parameter**

In `ContentPackage.swift`, add after `public var version: Int = 1`:

```swift
    /// App Store product that unlocks this package; nil for packages that are
    /// not sold (they always stay in preview).
    public var storeProductID: String?
```

Change the initializer signature and body to:

```swift
    public init(
        id: String, name: String, goal: LearningGoal, levelLower: String, levelUpper: String,
        version: Int = 1, skillWeights: SkillWeights = .vocabularyOnly, storeProductID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.levelLower = levelLower
        self.levelUpper = levelUpper
        self.version = version
        self.skillWeights = skillWeights
        self.storeProductID = storeProductID
    }
```

- [ ] **Step 2: Document — decode the optional field**

In `ContentDocuments.swift`, inside `ContentPackageDocument`, add after `public let version: Int`:

```swift
    /// Optional App Store product id; absent for packages that are not sold.
    public let storeProductID: String?
```

- [ ] **Step 3: Importer — validate and store**

In `ContentImporter.swift`, add to `ContentImportError` (after `case invalidVersion(Int)`):

```swift
    /// `storeProductID` is present but blank.
    case invalidStoreProductID
```

In `importPackage`, right after the `guard document.version >= 1 ...` block, add:

```swift
        if let productID = document.storeProductID,
           productID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ContentImportError.invalidStoreProductID
        }
```

and pass it to the model — change the `ContentPackage(...)` construction to:

```swift
        let package = ContentPackage(
            id: document.id, name: document.name, goal: goal,
            levelLower: document.levelLower, levelUpper: document.levelUpper,
            version: document.version, skillWeights: weights,
            storeProductID: document.storeProductID
        )
```

- [ ] **Step 4: Tests — extend the JSON builder and add three tests**

In `ContentImporterTests.swift`, change the `packageJSON` signature and head. Replace

```swift
        goal: String = "yds",
        itemType: String = "vocabulary"
    ) -> Data {
        """
        {
          "id": "test-package", "name": "Test Package", "goal": "\(goal)",
          "levelLower": "B2", "levelUpper": "C1",
          "version": \(version),
```

with

```swift
        goal: String = "yds",
        itemType: String = "vocabulary",
        storeProductID: String? = nil
    ) -> Data {
        let storeLine = storeProductID.map { #""storeProductID": "\#($0)","# } ?? ""
        return """
        {
          "id": "test-package", "name": "Test Package", "goal": "\(goal)",
          "levelLower": "B2", "levelUpper": "C1",
          \(storeLine)
          "version": \(version),
```

Add next to `test_importPackage_versionBelowOne_throws`:

```swift
    func test_importPackage_storeProductID_isStoredWhenPresent() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(
            from: packageJSON(storeProductID: "com.example.package"), into: context
        )
        XCTAssertEqual(package.storeProductID, "com.example.package")
    }

    func test_importPackage_storeProductID_absentIsNil() throws {
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: packageJSON(), into: context)
        XCTAssertNil(package.storeProductID)
    }

    func test_importPackage_blankStoreProductID_throws() throws {
        let context = try makeInMemoryContext()
        XCTAssertThrowsError(
            try ContentImporter.importPackage(from: packageJSON(storeProductID: "   "), into: context)
        ) { error in
            XCTAssertEqual(error as? ContentImportError, .invalidStoreProductID)
        }
    }
```

- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add LearningEngine
git commit -m "$(cat <<'EOF'
Add optional storeProductID to the content package model and importer

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Both must end green. `App Build` matters here because the App target's seeding tests import the real package through this code.

---

### Task 2: Stamp the YDS product id, package version 6

**Files:**
- Modify: `scripts/assemble-content.py`
- Regenerate: both derived JSON files
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`
- Modify: `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`

**Interfaces:**
- Consumes: Task 1's importer (`storeProductID` in the document header).
- Produces: bundled package version **6** with `storeProductID == "com.niinova22.englishapp.package.yds"`.

- [ ] **Step 1: Assembly script**

In `scripts/assemble-content.py`, extend the version comment block and value:

```python
# 6: Slice 8 stamps the package's App Store product id. Bumping this makes
# installed apps re-import the package so the new attribute is populated;
# every existing id is unchanged, so FSRS history survives the reseed.
PACKAGE_VERSION = 6
```

(keep the existing `# 4` and `# 5` comment lines above it), and in `assemble()` add the key to the package dict, after `"goal": "yds",`:

```python
        "storeProductID": "com.niinova22.englishapp.package.yds",
```

- [ ] **Step 2: Regenerate and confirm the drift**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
git diff --stat
```

Expected: both derived JSON files modified, and the diff shows only the version line and the new `storeProductID` line in each.

- [ ] **Step 3: Update the version assertions and assert the product id**

In `ContentImporterTests.swift`, in `test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion`, change `XCTAssertEqual(package.version, 5)` to `6` and add directly below it:

```swift
        XCTAssertEqual(package.storeProductID, "com.niinova22.englishapp.package.yds")
```

In `RealContentSeedingTests.swift`, in `test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsEveryItem`, change `XCTAssertEqual(package.version, 5)` to `6` and add below it the same `storeProductID` assertion.

Then search for any other hard-coded package version:

```bash
grep -rn "version, 5\|version: 5" LearningEngine/Tests App/Tests
```

Any remaining hit that refers to the real YDS package must become 6 (hits that use their own tiny fixture JSON stay unchanged).

- [ ] **Step 4: Commit, push, confirm both CI workflows green**

```bash
git add scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Stamp the YDS store product id and bump the package to version 6

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

### Task 3: Store domain — types, snapshot, `EntitlementStore`, fake service

**Files:**
- Create: `App/Sources/EnglishApp/Store/StoreTypes.swift`
- Create: `App/Sources/EnglishApp/Store/EntitlementSnapshot.swift`
- Create: `App/Sources/EnglishApp/Store/EntitlementStore.swift`
- Create: `App/Tests/EnglishAppTests/Store/FakePurchaseService.swift`
- Create: `App/Tests/EnglishAppTests/Store/EntitlementStoreTests.swift`

**Interfaces:**
- Produces (used by every later task): `StoreProduct` (`id`, `displayName`, `displayPrice`, `kind`), `PurchaseOutcome`, `StoreEntitlement`, `StoreError`, `PremiumProducts` (`monthly`, `yearly`, `all`, `kind(forProductID:)`), `PurchaseService`, `PackageProduct`, `EntitlementSnapshot`, `EntitlementStore` (`activeProductIDs`, `snapshot`, `onChange`, `isPremium`, `owns(_:)`, `start()`, `refresh()`, `apply(_:)`, `products(for:)`, `purchase(productID:)`, `restore()`), and the test double `FakePurchaseService`.

- [ ] **Step 1: `StoreTypes.swift`**

```swift
import Foundation

struct StoreProduct: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case package, premiumMonthly, premiumYearly }

    let id: String
    let displayName: String
    let displayPrice: String
    let kind: Kind
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
```

- [ ] **Step 2: `EntitlementSnapshot.swift`**

```swift
import Foundation

/// One installed package that can be bought.
struct PackageProduct: Equatable, Sendable {
    let packageID: String
    let productID: String
    let name: String
}

/// Lock-protected mirror of the entitlement state. `PackageAccessProvider` is
/// synchronous and not main-actor, so providers read this instead of the
/// observable, main-actor `EntitlementStore`.
final class EntitlementSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var activeIDs: Set<String>
    private var packageProducts: [String: PackageProduct] = [:]

    init(activeProductIDs: Set<String> = []) {
        self.activeIDs = activeProductIDs
    }

    var activeProductIDs: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return activeIDs
    }

    func replaceActiveProductIDs(_ ids: Set<String>) {
        lock.lock()
        activeIDs = ids
        lock.unlock()
    }

    /// Replaces the package → product table (called once after seeding).
    func registerPackages(_ products: [PackageProduct]) {
        lock.lock()
        packageProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.packageID, $0) })
        lock.unlock()
    }

    func packageProduct(forPackageID id: String) -> PackageProduct? {
        lock.lock()
        defer { lock.unlock() }
        return packageProducts[id]
    }
}
```

- [ ] **Step 3: `EntitlementStore.swift`**

```swift
import Foundation
import Observation

/// Single source of truth for what the learner has bought. UI observes
/// `activeProductIDs`; synchronous providers read `snapshot`.
@MainActor
@Observable
final class EntitlementStore {
    static let cacheKey = "store.activeProductIDs"

    private(set) var activeProductIDs: Set<String>

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
        let entitlements = await service.currentEntitlements()
        setActive(Set(entitlements.filter(\.isActive).map(\.productID)))
    }

    func apply(_ update: StoreEntitlement) {
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
```

- [ ] **Step 4: Test double `FakePurchaseService.swift`**

```swift
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
```

- [ ] **Step 5: `EntitlementStoreTests.swift`**

```swift
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
```

- [ ] **Step 6: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp/Store App/Tests/EnglishAppTests/Store
git commit -m "$(cat <<'EOF'
Add the entitlement store, snapshot and purchase-service protocol

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

### Task 4: Access providers, `AppState` wiring, tutor gate logic, DEBUG override

**Files:**
- Create: `App/Sources/EnglishApp/Store/StoreAccessProviders.swift`
- Create: `App/Sources/EnglishApp/Store/TutorAccess.swift`
- Modify: `App/Sources/EnglishApp/Access/PackageAccessProvider.swift`
- Modify: `App/Sources/EnglishApp/AppState.swift`
- Modify: `App/Sources/EnglishApp/EnglishAppApp.swift`
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift`
- Create: `App/Sources/EnglishApp/Store/StoreKitPurchaseService.swift` (a **compile stub** in this task, replaced in Task 5 — see Step 6)
- Test: `App/Tests/EnglishAppTests/Store/AppStateStoreTests.swift`

**Interfaces:**
- Consumes: Task 3's types, `EntitlementStore`, `EntitlementSnapshot`, `FakePurchaseService`.
- Produces: `PremiumAccessProvider`, `StoreKitPackageAccessProvider`, `SnapshotPremiumAccessProvider`, `DeveloperOverride` (DEBUG), `TutorAccess`, `AppState.init(service:defaults:)`, `AppState.entitlements`, `AppState.accessProvider`, `AppState.premiumProvider`, `AppState.registerPackageProducts(from:)`, `AppState.tutorAccess`.

- [ ] **Step 1: `StoreAccessProviders.swift`**

```swift
import Foundation
import LearningEngine

/// Whether the AI features are unlocked. Independent of package ownership.
protocol PremiumAccessProvider {
    var isPremium: Bool { get }
}

/// `.owned` when the package's store product is active, `.preview` otherwise.
/// A package with no registered store product is always a preview.
struct StoreKitPackageAccessProvider: PackageAccessProvider {
    let snapshot: EntitlementSnapshot

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        guard let product = snapshot.packageProduct(forPackageID: id) else { return .preview }
        return snapshot.activeProductIDs.contains(product.productID) ? .owned : .preview
    }
}

struct SnapshotPremiumAccessProvider: PremiumAccessProvider {
    let snapshot: EntitlementSnapshot

    var isPremium: Bool {
        !snapshot.activeProductIDs.isDisjoint(with: PremiumProducts.all)
    }
}

#if DEBUG
/// Developer shortcut: never compiled into Release, so it cannot ship.
enum DeveloperOverride {
    static let unlockAllKey = "dev.unlockAllPackages"
}

struct DeveloperOverridePackageAccessProvider: PackageAccessProvider {
    let base: any PackageAccessProvider
    let defaults: UserDefaults

    func accessLevel(forPackageID id: String) -> PackageAccessLevel {
        defaults.bool(forKey: DeveloperOverride.unlockAllKey) ? .owned : base.accessLevel(forPackageID: id)
    }
}

struct DeveloperOverridePremiumAccessProvider: PremiumAccessProvider {
    let base: any PremiumAccessProvider
    let defaults: UserDefaults

    var isPremium: Bool {
        defaults.bool(forKey: DeveloperOverride.unlockAllKey) || base.isPremium
    }
}
#endif
```

- [ ] **Step 2: `TutorAccess.swift`**

```swift
import Foundation

/// The single decision every tutor entry point makes.
enum TutorAccess: Equatable {
    /// No tutor on this device/build: entry points stay hidden.
    case unavailable
    /// The tutor exists but the learner is not premium: entry points stay
    /// visible and open the premium paywall.
    case needsPremium
    case allowed

    static func resolve(isTutorAvailable: Bool, isPremium: Bool) -> TutorAccess {
        guard isTutorAvailable else { return .unavailable }
        return isPremium ? .allowed : .needsPremium
    }
}

extension AppState {
    var tutorAccess: TutorAccess {
        // Reading `dataGeneration` registers observation, so views that read
        // this re-render when an entitlement change bumps it.
        _ = dataGeneration
        return TutorAccess.resolve(isTutorAvailable: isTutorAvailable, isPremium: premiumProvider.isPremium)
    }
}
```

- [ ] **Step 3: `PackageAccessProvider.swift` — keep only the protocol**

Replace the whole file with:

```swift
import Foundation
import LearningEngine

/// Entitlement boundary. Screens and planners only ever talk to this
/// protocol; the StoreKit-backed implementation lives in
/// `Store/StoreAccessProviders.swift`.
protocol PackageAccessProvider {
    func accessLevel(forPackageID id: String) -> PackageAccessLevel
}
```

- [ ] **Step 4: `AppState.swift`**

Change the imports and the top of the class. Replace

```swift
import Foundation
import TutorEngine

@MainActor
@Observable
final class AppState {
    private(set) var dataGeneration = 0
    private(set) var tutorEngine: (any TutorEngine)?

    /// Swapped for a StoreKit-backed provider in Slice 8.
    let accessProvider: any PackageAccessProvider = DevelopmentPackageAccessProvider()

    func bumpDataGeneration() {
        dataGeneration += 1
    }
```

with

```swift
import Foundation
import SwiftData
import LearningEngine
import TutorEngine

@MainActor
@Observable
final class AppState {
    private(set) var dataGeneration = 0
    private(set) var tutorEngine: (any TutorEngine)?

    @ObservationIgnored let entitlements: EntitlementStore
    @ObservationIgnored let accessProvider: any PackageAccessProvider
    @ObservationIgnored let premiumProvider: any PremiumAccessProvider

    init(service: any PurchaseService = StoreKitPurchaseService(), defaults: UserDefaults = .standard) {
        let store = EntitlementStore(service: service, defaults: defaults)
        entitlements = store
        let packages = StoreKitPackageAccessProvider(snapshot: store.snapshot)
        let premium = SnapshotPremiumAccessProvider(snapshot: store.snapshot)
        #if DEBUG
        accessProvider = DeveloperOverridePackageAccessProvider(base: packages, defaults: defaults)
        premiumProvider = DeveloperOverridePremiumAccessProvider(base: premium, defaults: defaults)
        #else
        accessProvider = packages
        premiumProvider = premium
        #endif
        store.onChange = { [weak self] in self?.bumpDataGeneration() }
    }

    func bumpDataGeneration() {
        dataGeneration += 1
    }

    /// Fills the package → store product table from the installed packages.
    /// Call once after content seeding, before the first screen renders.
    func registerPackageProducts(from context: ModelContext) {
        let packages = (try? context.fetch(FetchDescriptor<ContentPackage>())) ?? []
        entitlements.snapshot.registerPackages(packages.compactMap { package in
            package.storeProductID.map { PackageProduct(packageID: package.id, productID: $0, name: package.name) }
        })
    }
```

and add the premium guard at the top of `loadTutorEngineIfNeeded()`:

```swift
    func loadTutorEngineIfNeeded() async {
        guard premiumProvider.isPremium else { return }
        guard tutorEngine == nil else { return }
```

(replace only the first line of the existing body, `guard tutorEngine == nil else { return }`, keep everything below it).

- [ ] **Step 5: `EnglishAppApp.swift` and `ProfileView.swift`**

`EnglishAppApp.swift` — replace the file body with:

```swift
import SwiftUI
import SwiftData

@main
struct EnglishAppApp: App {
    let modelContainer = AppModelContainer.make()
    @State private var appState: AppState

    init() {
        let context = ModelContext(modelContainer)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let state = AppState()
        state.registerPackageProducts(from: context)
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task { await appState.entitlements.start() }
        }
        .modelContainer(modelContainer)
        .environment(appState)
    }
}
```

`ProfileView.swift` — replace the `@AppStorage` line

```swift
    @AppStorage(DevelopmentPackageAccessProvider.unlockAllKey) private var unlockAll = false
```

with

```swift
    #if DEBUG
    @AppStorage(DeveloperOverride.unlockAllKey) private var unlockAll = false
    #endif
```

and replace the `section("GELİŞTİRİCİ")` block with

```swift
                section("GELİŞTİRİCİ") {
                    #if DEBUG
                    Toggle("Tüm paketleri aç", isOn: $unlockAll)
                        .tint(Theme.primary)
                        .onChange(of: unlockAll) { _, _ in appState.bumpDataGeneration() }
                    Divider()
                    #endif
                    Button("Yerel verileri sıfırla", role: .destructive) { showResetConfirmation = true }
                        .foregroundStyle(Theme.danger)
                }
```

- [ ] **Step 6: Compile stub for the live service**

`AppState.init` names `StoreKitPurchaseService`, which Task 5 writes for real. Create `App/Sources/EnglishApp/Store/StoreKitPurchaseService.swift` now with an inert implementation so this task compiles and is CI-verifiable on its own:

```swift
import Foundation

/// Inert placeholder replaced by the real StoreKit wrapper in the next task.
struct StoreKitPurchaseService: PurchaseService {
    func products(for ids: [String]) async throws -> [StoreProduct] { [] }
    func purchase(productID: String) async throws -> PurchaseOutcome { .cancelled }
    func currentEntitlements() async -> [StoreEntitlement] { [] }
    var entitlementUpdates: AsyncStream<StoreEntitlement> { AsyncStream { $0.finish() } }
    func restore() async throws {}
}
```

- [ ] **Step 7: Tests — `AppStateStoreTests.swift`**

```swift
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
```

- [ ] **Step 8: Search for stragglers, commit, push, confirm both CI workflows green**

```bash
grep -rn "DevelopmentPackageAccessProvider" App LearningEngine
```

Expected: no hits in `App/` or `LearningEngine/` (old plan documents under `docs/` are history and stay). Then:

```bash
git add App
git commit -m "$(cat <<'EOF'
Wire StoreKit-backed access providers into AppState and gate the tutor load on premium

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

If an existing test fails, do not weaken it: `TodayPlanCoordinatorTests` and `CoursePathViewModelTests` inject `FixedAccessProvider` and must be unaffected.

---

### Task 5: Live StoreKit wrapper, local `.storekit` file, store setup guide

**Files:**
- Replace: `App/Sources/EnglishApp/Store/StoreKitPurchaseService.swift`
- Create: `App/StoreKit/Products.storekit`
- Create: `docs/store-setup.md`

**Interfaces:**
- Consumes: `PurchaseService`, `StoreProduct`, `StoreEntitlement`, `PurchaseOutcome`, `StoreError`, `PremiumProducts` (Task 3).
- Produces: the real `StoreKitPurchaseService` (same type name, no callers change).

- [ ] **Step 1: Replace `StoreKitPurchaseService.swift` with the live wrapper**

The wrapper holds no decisions: it translates StoreKit values into the protocol's types and nothing else.

```swift
import Foundation
import StoreKit

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
```

- [ ] **Step 2: `App/StoreKit/Products.storekit`**

Local-testing configuration for Xcode (Edit Scheme → Run → Options → StoreKit Configuration). It sits outside `Sources/`, so it is not bundled. The prices are local sample values only.

```json
{
  "identifier" : "A1B2C3D4",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "299.99",
      "familyShareable" : false,
      "internalID" : "6740000001",
      "localizations" : [
        {
          "description" : "YDS paketinin tüm üniteleri ve dersleri.",
          "displayName" : "YDS Paketi",
          "locale" : "tr"
        }
      ],
      "productID" : "com.niinova22.englishapp.package.yds",
      "referenceName" : "YDS Paketi",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {},
  "subscriptionGroups" : [
    {
      "id" : "21000001",
      "localizations" : [],
      "name" : "ai_premium",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "49.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "6740000002",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Öğretmene Sor ve sohbet, aylık.",
              "displayName" : "AI Premium (aylık)",
              "locale" : "tr"
            }
          ],
          "productID" : "com.niinova22.englishapp.premium.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "AI Premium aylık",
          "subscriptionGroupID" : "21000001",
          "type" : "RecurringSubscription",
          "winbackOffers" : []
        },
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "399.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "6740000003",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Öğretmene Sor ve sohbet, yıllık.",
              "displayName" : "AI Premium (yıllık)",
              "locale" : "tr"
            }
          ],
          "productID" : "com.niinova22.englishapp.premium.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "AI Premium yıllık",
          "subscriptionGroupID" : "21000001",
          "type" : "RecurringSubscription",
          "winbackOffers" : []
        }
      ]
    }
  ],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

- [ ] **Step 3: `docs/store-setup.md`**

Write this file (Turkish, since the person doing the App Store Connect work is the user):

```markdown
# Mağaza kurulumu ve satın alma testi (Slice 8)

Kod tarafı hazır olduğunda, satın almaların gerçekten çalışması için aşağıdaki
adımlar App Store Connect'te elle yapılır. CI gerçek StoreKit'i çalıştıramaz.

## 1. App Store Connect

1. **Paid Applications** sözleşmesini kabul et; vergi ve banka bilgilerini doldur.
2. Uygulamada **Uygulama İçi Satın Almalar** altında şu ürünleri oluştur
   (kimlikler birebir aynı olmalı; silinen kimlik yeniden kullanılamaz):

   | Ürün | Tür | Ürün kimliği |
   |---|---|---|
   | YDS Paketi | Tüketilmeyen (Non-Consumable) | `com.niinova22.englishapp.package.yds` |
   | AI Premium aylık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.monthly` |
   | AI Premium yıllık | Otomatik yenilenen abonelik | `com.niinova22.englishapp.premium.yearly` |

3. İki aboneliği **aynı abonelik grubunda** (`ai_premium`) oluştur; yıllık olanı
   aylığın üstüne yerleştir.
4. Her ürüne Türkçe görünen ad ve açıklama gir, fiyat belirle, "Aile Paylaşımı"
   kapalı kalsın.
5. Her ürün için inceleme ekran görüntüsü olarak paywall sayfasının görüntüsünü ekle.
6. **Gizlilik politikası** ve **kullanım şartları** URL'lerini hazırla.
   `App/Sources/EnglishApp/Store/StoreLinks.swift` içindeki `privacyPolicy` değerini
   yayımlanan gizlilik politikası adresiyle doldur (abonelik uygulamaları bu
   bağlantı olmadan reddedilir). Kullanım şartları için Apple'ın standart EULA'sı
   kullanılır.
7. **Sandbox test hesabı** oluştur (Kullanıcılar ve Erişim → Sandbox).

## 2. Yerel geliştirme (Xcode)

`App/StoreKit/Products.storekit` dosyasını Edit Scheme → Run → Options →
StoreKit Configuration altında seç. Fiyatlar yalnızca yerel örnek değerlerdir.

## 3. TestFlight'ta elle doğrulama (CI'nin yapamadığı kısım)

Sandbox hesabıyla, gerçek cihazda:

- [ ] Ders Yolu'nda kilitli bir derse dokun → "Paketi aç" → fiyat görünüyor mu?
- [ ] Satın al → Apple ödeme sayfası → onay → kilitler açıldı mı, Bugün ve Ders Yolu yenilendi mi?
- [ ] Uygulamayı kapatıp aç → paket hâlâ açık mı? Uçak modunda aç → hâlâ açık mı?
- [ ] Profil → Satın alımları geri yükle → çalışıyor mu (silip yeniden yükledikten sonra)?
- [ ] Tutor sekmesi → kilitli ekran → "AI Premium'a geç" → aylık/yıllık seçimi → abonelik.
- [ ] Abonelik sonrası "Öğretmene Sor" ve Tutor sohbeti açılıyor mu?
- [ ] Profil → Aboneliği yönet açılıyor mu?
- [ ] Bir gramer dersini uçtan uca dene: kart → 8 veya 10 soru → özet → "Tekrar: konu" zamanlaması.
- [ ] Ask to Buy (çocuk hesabı) bekleme durumu: "Onay bekleniyor" görünüyor mu?

Not: Release/TestFlight derlemelerinde geliştirici "Tüm paketleri aç" anahtarı
yoktur (yalnızca Debug). TestFlight'ta kilitli içeriği görmek için sandbox
satın alması gerekir; bu yüzden ürünler App Store Connect'te hazır olmadan
TestFlight'ta kilitli üniteler açılamaz.
```

- [ ] **Step 4: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp/Store/StoreKitPurchaseService.swift App/StoreKit docs/store-setup.md
git commit -m "$(cat <<'EOF'
Add the live StoreKit 2 purchase service, a local storekit file and the store setup guide

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

`App Build` compiling this file against the real StoreKit SDK is its only verification.

---

### Task 6: `PaywallViewModel`

**Files:**
- Create: `App/Sources/EnglishApp/Store/PaywallViewModel.swift`
- Test: `App/Tests/EnglishAppTests/Store/PaywallViewModelTests.swift`

**Interfaces:**
- Consumes: `EntitlementStore`, `StoreProduct`, `PurchaseOutcome`, `PremiumProducts` (Task 3), `FakePurchaseService`, `StoreProduct.yds/.monthly/.yearly` (test extension from Task 3).
- Produces: `PaywallMode` (`.package(productID:packageName:)`, `.premium`, `Identifiable`, `productIDs`), `PaywallViewModel` (`state`, `products`, `notice`, `selectedProductID`, `selectedProduct`, `title`, `isAlreadyOwned`, `load()`, `purchase()`, `restore()`, `dismissError()`).

- [ ] **Step 1: `PaywallViewModel.swift`**

```swift
import Foundation
import Observation

enum PaywallMode: Equatable, Identifiable {
    case package(productID: String, packageName: String)
    case premium

    var id: String {
        switch self {
        case .package(let productID, _): return "package-\(productID)"
        case .premium: return "premium"
        }
    }

    /// Product ids in display order.
    var productIDs: [String] {
        switch self {
        case .package(let productID, _): return [productID]
        case .premium: return PremiumProducts.all
        }
    }
}

@MainActor
@Observable
final class PaywallViewModel {
    enum State: Equatable {
        case loadingProducts
        case ready
        case loadFailed
        case purchasing
        /// Ask to Buy: waiting for a parent's approval.
        case pending
        case succeeded
        case failed(String)
    }

    let mode: PaywallMode
    private(set) var state: State = .loadingProducts
    private(set) var products: [StoreProduct] = []
    /// A non-error message shown under the buttons (e.g. nothing to restore).
    private(set) var notice: String?
    var selectedProductID: String?

    @ObservationIgnored private let store: EntitlementStore

    init(mode: PaywallMode, store: EntitlementStore) {
        self.mode = mode
        self.store = store
    }

    var title: String {
        switch mode {
        case .package(_, let packageName): return packageName
        case .premium: return "AI Premium"
        }
    }

    var selectedProduct: StoreProduct? {
        products.first { $0.id == selectedProductID }
    }

    var isAlreadyOwned: Bool {
        mode.productIDs.contains { store.owns($0) }
    }

    func load() async {
        state = .loadingProducts
        notice = nil
        do {
            let fetched = try await store.products(for: mode.productIDs)
            products = mode.productIDs.compactMap { id in fetched.first { $0.id == id } }
            guard !products.isEmpty else {
                state = .loadFailed
                return
            }
            if selectedProduct == nil {
                let preferred = mode == .premium ? PremiumProducts.yearly : mode.productIDs[0]
                selectedProductID = products.contains { $0.id == preferred } ? preferred : products[0].id
            }
            state = .ready
        } catch {
            state = .loadFailed
        }
    }

    func purchase() async {
        guard state == .ready || isFailed, let productID = selectedProductID else { return }
        state = .purchasing
        notice = nil
        do {
            switch try await store.purchase(productID: productID) {
            case .purchased: state = .succeeded
            case .pending: state = .pending
            case .cancelled: state = .ready
            }
        } catch {
            state = .failed("Satın alma tamamlanamadı. Bir süre sonra tekrar dene.")
        }
    }

    func restore() async {
        guard state == .ready || isFailed else { return }
        state = .purchasing
        notice = nil
        do {
            try await store.restore()
            if isAlreadyOwned {
                state = .succeeded
            } else {
                notice = "Bu hesapta geri yüklenecek bir satın alım bulunamadı."
                state = .ready
            }
        } catch {
            state = .failed("Satın alımlar geri yüklenemedi. Bir süre sonra tekrar dene.")
        }
    }

    func dismissError() {
        if isFailed { state = .ready }
    }

    private var isFailed: Bool {
        if case .failed = state { return true }
        return false
    }
}
```

- [ ] **Step 2: `PaywallViewModelTests.swift`**

```swift
import XCTest
@testable import EnglishApp

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

    private let packageMode = PaywallMode.package(productID: "com.niinova22.englishapp.package.yds", packageName: "YDS: Academic Vocabulary I")

    func test_load_packageMode_isReadyWithTheSingleProductSelected() async {
        let vm = PaywallViewModel(mode: packageMode, store: makeStore(FakePurchaseService(products: [.yds, .monthly])))
        XCTAssertEqual(vm.state, .loadingProducts)
        await vm.load()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.products, [.yds])
        XCTAssertEqual(vm.selectedProductID, "com.niinova22.englishapp.package.yds")
        XCTAssertEqual(vm.title, "YDS: Academic Vocabulary I")
    }

    func test_load_premiumMode_listsMonthlyThenYearly_andPreselectsYearly() async {
        let vm = PaywallViewModel(mode: .premium, store: makeStore(FakePurchaseService(products: [.yearly, .monthly, .yds])))
        await vm.load()
        XCTAssertEqual(vm.state, .ready)
        XCTAssertEqual(vm.products.map(\.id), [PremiumProducts.monthly, PremiumProducts.yearly])
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
        XCTAssertEqual(vm.state, .failed("Satın alma tamamlanamadı. Bir süre sonra tekrar dene."))

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
        XCTAssertEqual(vm.notice, "Bu hesapta geri yüklenecek bir satın alım bulunamadı.")
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
        XCTAssertEqual(vm.state, .failed("Satın alımlar geri yüklenemedi. Bir süre sonra tekrar dene."))
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
}
```

- [ ] **Step 3: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp/Store/PaywallViewModel.swift App/Tests/EnglishAppTests/Store/PaywallViewModelTests.swift
git commit -m "$(cat <<'EOF'
Add the paywall view model state machine

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

### Task 7: Paywall UI and the locked-lesson entry points

**Files:**
- Create: `App/Sources/EnglishApp/Store/StoreLinks.swift`
- Create: `App/Sources/EnglishApp/Store/PaywallView.swift`
- Create: `App/Sources/EnglishApp/Store/LockedLessonPrompt.swift`
- Modify: `App/Sources/EnglishApp/CoursePath/CoursePathView.swift`
- Modify: `App/Sources/EnglishApp/Today/TodayPlanView.swift`

**Interfaces:**
- Consumes: `PaywallMode`, `PaywallViewModel` (Task 6), `EntitlementStore`, `AppState.entitlements/.accessProvider`, `TodayPlanCoordinator.activePackage()`, `Theme`, `PaperCard`, `PrimaryButtonStyle`.
- Produces: `PaywallView(mode:store:)`, `StoreLinks`, `LockedLesson`, `PaywallTarget.activePackage(context:appState:)`, `View.lockedLessonPrompts(_:)`.

There are no unit tests for SwiftUI views in this codebase; the view logic they need is already covered by `PaywallViewModelTests`. `App Build` compiling is the gate.

- [ ] **Step 1: `StoreLinks.swift`**

```swift
import Foundation

/// Legal links shown under the subscription button.
enum StoreLinks {
    /// Apple's standard license agreement satisfies the "terms of use"
    /// requirement for auto-renewing subscriptions.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")

    /// Set to the published privacy policy URL before the first App Store
    /// submission (docs/store-setup.md step 6). The paywall hides the link
    /// while this is nil.
    static let privacyPolicy: URL? = nil
}
```

- [ ] **Step 2: `PaywallView.swift`**

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let mode: PaywallMode
    let store: EntitlementStore
    @State private var viewModel: PaywallViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let viewModel {
                    content(viewModel).padding()
                } else {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }.foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .task {
            let vm = viewModel ?? PaywallViewModel(mode: mode, store: store)
            viewModel = vm
            await vm.load()
        }
        .onChange(of: viewModel?.state) { _, state in
            if state == .succeeded { dismiss() }
        }
    }

    @ViewBuilder
    private func content(_ vm: PaywallViewModel) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(vm.title).font(.serifTitle(.largeTitle)).foregroundStyle(Theme.ink)

            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(benefits, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.ink)
                            .labelStyle(BenefitLabelStyle())
                    }
                }
            }

            if vm.isAlreadyOwned {
                Text("Bu satın alım zaten hesabında açık.")
                    .font(.subheadline).foregroundStyle(Theme.primary)
            } else {
                purchaseSection(vm)
            }
        }
    }

    @ViewBuilder
    private func purchaseSection(_ vm: PaywallViewModel) -> some View {
        switch vm.state {
        case .loadingProducts:
            ProgressView("Fiyatlar yükleniyor...").frame(maxWidth: .infinity)
        case .loadFailed:
            VStack(spacing: 10) {
                Text("Fiyatlar yüklenemedi.").foregroundStyle(Theme.secondaryInk)
                Button("Tekrar dene") { Task { await vm.load() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .pending:
            Text("Onay bekleniyor. Satın alım onaylanınca otomatik açılacak.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
        case .ready, .purchasing, .succeeded, .failed:
            readyControls(vm)
        }
    }

    @ViewBuilder
    private func readyControls(_ vm: PaywallViewModel) -> some View {
        let isBusy = vm.state == .purchasing
        VStack(alignment: .leading, spacing: 12) {
            if mode == .premium {
                ForEach(vm.products, id: \.id) { product in
                    Button {
                        vm.selectedProductID = product.id
                    } label: {
                        HStack {
                            Text(product.displayName).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(product.displayPrice).foregroundStyle(Theme.primary)
                        }
                        .padding()
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(vm.selectedProductID == product.id ? Theme.primary : Theme.border, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if case .failed(let message) = vm.state {
                Text(message).font(.subheadline).foregroundStyle(Theme.danger)
            }
            if let notice = vm.notice {
                Text(notice).font(.subheadline).foregroundStyle(Theme.secondaryInk)
            }

            Button {
                Task { await vm.purchase() }
            } label: {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(purchaseTitle(vm))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isBusy || vm.selectedProduct == nil)

            Button("Satın alımları geri yükle") { Task { await vm.restore() } }
                .font(.subheadline).foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .disabled(isBusy)

            if mode == .premium { disclosure }
        }
    }

    private func purchaseTitle(_ vm: PaywallViewModel) -> String {
        let price = vm.selectedProduct?.displayPrice ?? ""
        return mode == .premium ? "Abone ol · \(price)" : "Satın al · \(price)"
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Abonelik, dönem bitiminden en az 24 saat önce iptal edilmezse otomatik olarak yenilenir. Ödeme, satın alma onayında Apple ID hesabından alınır. Aboneliği Ayarlar > Apple ID > Abonelikler bölümünden yönetebilir ve iptal edebilirsin.")
                .font(.caption).foregroundStyle(Theme.secondaryInk)
            HStack(spacing: 16) {
                if let terms = StoreLinks.termsOfUse { Link("Kullanım şartları", destination: terms) }
                if let privacy = StoreLinks.privacyPolicy { Link("Gizlilik politikası", destination: privacy) }
            }
            .font(.caption)
        }
    }

    private var benefits: [String] {
        switch mode {
        case .package:
            return [
                "Paketin tüm üniteleri ve dersleri açılır",
                "Kelime, gramer ve okuma çalışmaları",
                "Tek seferlik ödeme, abonelik yok",
            ]
        case .premium:
            return [
                "Öğretmene Sor: sorunun cevabını Türkçe açıklar",
                "Öğretmenle serbest sohbet",
                "Çalışma koçu (yakında)",
                "İstediğin zaman iptal edebilirsin",
            ]
        }
    }
}

private struct BenefitLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon.foregroundStyle(Theme.primary)
            configuration.title.font(.subheadline)
        }
    }
}
```

`Theme.surface` and `Theme.border` already exist (used by `PaperCard`). Drop the unused `import StoreKit` line if the compiler warns about it; the view uses only its own types.

- [ ] **Step 3: `LockedLessonPrompt.swift`**

```swift
import SwiftUI
import SwiftData

struct LockedLesson: Identifiable, Equatable {
    let id = UUID()
    let title: String
}

@MainActor
enum PaywallTarget {
    /// The paywall for the learner's active package, or nil when that package
    /// has no store product (it then stays a preview with no buy button).
    static func activePackage(context: ModelContext, appState: AppState) -> PaywallMode? {
        guard let package = try? TodayPlanCoordinator(
                context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider
              ).activePackage(),
              let product = appState.entitlements.snapshot.packageProduct(forPackageID: package.id)
        else { return nil }
        return .package(productID: product.productID, packageName: product.name)
    }
}

struct LockedLessonSheet: View {
    let lessonTitle: String
    let canPurchase: Bool
    let onUnlock: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Bu ders paketin tam sürümünde")
                .font(.serifTitle(.title3)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(lessonTitle).font(.subheadline).foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            if canPurchase {
                Button("Paketi aç", action: onUnlock).buttonStyle(PrimaryButtonStyle())
            }
            Button("Kapat", action: onClose).foregroundStyle(Theme.secondaryInk)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
    }
}

/// Presents the locked-lesson sheet and, on "Paketi aç", the package paywall.
/// The paywall opens from the first sheet's `onDismiss` so the two sheets never
/// change in the same frame.
struct LockedLessonPresenter: ViewModifier {
    @Binding var lockedLesson: LockedLesson?
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var paywall: PaywallMode?
    @State private var pendingPaywall: PaywallMode?

    func body(content: Content) -> some View {
        content
            .sheet(item: $lockedLesson, onDismiss: {
                paywall = pendingPaywall
                pendingPaywall = nil
            }) { locked in
                let target = PaywallTarget.activePackage(context: context, appState: appState)
                LockedLessonSheet(
                    lessonTitle: locked.title,
                    canPurchase: target != nil,
                    onUnlock: {
                        pendingPaywall = target
                        lockedLesson = nil
                    },
                    onClose: { lockedLesson = nil }
                )
                .presentationDetents([.medium])
            }
            .sheet(item: $paywall) { mode in
                PaywallView(mode: mode, store: appState.entitlements)
            }
    }
}

extension View {
    func lockedLessonPrompts(_ lockedLesson: Binding<LockedLesson?>) -> some View {
        modifier(LockedLessonPresenter(lockedLesson: lockedLesson))
    }
}
```

- [ ] **Step 4: `CoursePathView.swift` — use the prompt**

Add the state next to the others:

```swift
    @State private var lockedLesson: LockedLesson?
```

In `handle(_:)`, replace

```swift
        case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)
```

with

```swift
        case .locked(let title): lockedLesson = LockedLesson(title: title)
```

and add the modifier to the `NavigationStack`, next to `.alert(...)`:

```swift
        .lockedLessonPrompts($lockedLesson)
```

- [ ] **Step 5: `TodayPlanView.swift` — same change**

Add `@State private var lockedLesson: LockedLesson?` next to `infoMessage`, replace the identical `case .locked(let title): infoMessage = ("Bu ders paketin tam sürümünde", title)` line in `handle(_:)` with `case .locked(let title): lockedLesson = LockedLesson(title: title)`, and add `.lockedLessonPrompts($lockedLesson)` to the same view chain that already carries the `.alert(...)`/`.fullScreenCover` modifiers.

- [ ] **Step 6: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp
git commit -m "$(cat <<'EOF'
Add the paywall screen and open it from locked lessons

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

If `App Build` fails on a SwiftUI detail (for example the `#Preview`-free `let` inside a `@ViewBuilder`), fix the smallest thing; do not restructure the view model.

---

### Task 8: Premium gate on the Tutor tab and the "Öğretmene Sor" buttons

**Files:**
- Modify: `App/Sources/EnglishApp/Tutor/TutorTabView.swift`
- Modify: `App/Sources/EnglishApp/Study/StudySessionView.swift`
- Modify: `App/Sources/EnglishApp/Practice/PracticeSessionView.swift`

**Interfaces:**
- Consumes: `AppState.tutorAccess` / `TutorAccess` (Task 4, unit-tested), `PaywallView`, `PaywallMode.premium`, `AppState.entitlements`.
- Produces: no new types. Behaviour: without premium, the tutor never loads and the entry points open the premium paywall.

- [ ] **Step 1: `TutorTabView.swift` — locked state**

Add state and replace the `body` and `load()`:

```swift
    @State private var showPaywall = false

    var body: some View {
        Group {
            if appState.tutorAccess == .needsPremium {
                lockedState
            } else if let engine = appState.tutorEngine {
                TutorChatView(engine: engine)
            } else if isLoading {
                ProgressView("Öğretmen yükleniyor...")
                    .tint(Theme.primary)
                    .foregroundStyle(Theme.secondaryInk)
            } else {
                VStack(spacing: 12) {
                    if loadFailed {
                        Text("Öğretmen yüklenemedi.")
                            .foregroundStyle(Theme.secondaryInk)
                    }
                    Button("Öğretmeni yükle") { Task { await load() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: 240)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.paper.ignoresSafeArea())
        .task(id: appState.tutorAccess) { await load() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(mode: .premium, store: appState.entitlements)
        }
    }

    private var lockedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(Theme.accent)
            Text("Öğretmen AI Premium ile açılır")
                .font(.serifTitle(.title3)).foregroundStyle(Theme.ink)
            Text("Sorularını Türkçe açıklatabilir ve öğretmenle sohbet edebilirsin.")
                .font(.subheadline).foregroundStyle(Theme.secondaryInk)
                .multilineTextAlignment(.center)
            Button("AI Premium'a geç") { showPaywall = true }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
        }
        .padding(24)
    }

    private func load() async {
        guard appState.tutorAccess == .allowed else { return }
        guard appState.tutorEngine == nil, !isLoading else { return }
        isLoading = true
        await appState.loadTutorEngineIfNeeded()
        isLoading = false
        loadFailed = appState.tutorEngine == nil
    }
```

(Keep the file's existing doc comment and the two `@State` properties `isLoading`, `loadFailed`; only `body`, `load()` and the new state/`lockedState` change.)

- [ ] **Step 2: `StudySessionView.swift` — Ask button opens the paywall without premium**

Add next to the other `@State` tutor properties:

```swift
    @State private var showPremiumPaywall = false
```

At the top of `openTutor()`, before `guard !isLoadingTutor else { return }`, add:

```swift
        switch appState.tutorAccess {
        case .unavailable: return
        case .needsPremium:
            showPremiumPaywall = true
            return
        case .allowed: break
        }
```

and attach, next to the existing `.sheet(isPresented: $showTutorSheet) { ... }` (line ~77):

```swift
                .sheet(isPresented: $showPremiumPaywall) {
                    PaywallView(mode: .premium, store: appState.entitlements)
                }
```

- [ ] **Step 3: `PracticeSessionView.swift` — same change**

Add `@State private var showPremiumPaywall = false`; add the same `switch appState.tutorAccess { ... }` block at the top of its `openTutor()`; and attach the same `.sheet(isPresented: $showPremiumPaywall) { PaywallView(mode: .premium, store: appState.entitlements) }` next to its existing `.sheet(isPresented: $showTutorSheet)` (line ~33).

- [ ] **Step 4: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp
git commit -m "$(cat <<'EOF'
Gate the tutor tab and Öğretmene Sor buttons behind AI Premium

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

### Task 9: Profil → "Satın alımlar"

**Files:**
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift`

**Interfaces:**
- Consumes: `AppState.entitlements`, `AppState.premiumProvider`, `PaywallView`, `PaywallTarget`, `EntitlementStore.restore()`, StoreKit's `AppStore.showManageSubscriptions(in:)`.
- Produces: a "SATIN ALIMLAR" section; no new types.

- [ ] **Step 1: State and imports**

Add `import StoreKit` and `import UIKit` at the top of `ProfileView.swift`, then add next to the other `@State` properties:

```swift
    @State private var paywall: PaywallMode?
    @State private var restoreMessage: String?
    @State private var isRestoring = false
```

- [ ] **Step 2: The section**

Insert a new section between `section("SEVİYEM") { ... }` and `section("İSTATİSTİK") { ... }`:

```swift
                section("SATIN ALIMLAR") {
                    // Registers observation so the rows update after a purchase.
                    let _ = appState.dataGeneration
                    row("Paket", stats?.accessLevel == .owned ? "Tam sürüm" : "Önizleme", tint: Theme.accent)
                    if stats?.accessLevel != .owned,
                       let target = PaywallTarget.activePackage(context: context, appState: appState) {
                        Button("Paketi aç") { paywall = target }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    row("AI Premium", appState.premiumProvider.isPremium ? "Aktif" : "Kapalı", tint: Theme.accent)
                    if !appState.premiumProvider.isPremium {
                        Button("AI Premium'a geç") { paywall = .premium }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    } else {
                        Button("Aboneliği yönet") { Task { await showManageSubscriptions() } }
                            .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    }
                    Divider()
                    Button(isRestoring ? "Geri yükleniyor..." : "Satın alımları geri yükle") {
                        Task { await restorePurchases() }
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.primary)
                    .disabled(isRestoring)
                    if let restoreMessage {
                        Text(restoreMessage).font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                }
```

- [ ] **Step 3: Sheet and helpers**

Add next to the existing `.sheet(isPresented: $showLevelTestSheet)`:

```swift
        .sheet(item: $paywall) { mode in
            PaywallView(mode: mode, store: appState.entitlements)
        }
```

and add these methods next to `refresh()`:

```swift
    private func restorePurchases() async {
        isRestoring = true
        restoreMessage = nil
        do {
            try await appState.entitlements.restore()
            restoreMessage = "Satın alımların güncellendi."
        } catch {
            restoreMessage = "Satın alımlar geri yüklenemedi. Bir süre sonra tekrar dene."
        }
        isRestoring = false
    }

    private func showManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
    }
```

The section re-renders on purchases: `refresh()` already runs on `appState.dataGeneration` changes (recomputing `stats?.accessLevel`), and the `let _ = appState.dataGeneration` line makes the `premiumProvider` rows observe the same counter.

- [ ] **Step 4: Commit, push, confirm both CI workflows green**

```bash
git add App/Sources/EnglishApp/Profile/ProfileView.swift
git commit -m "$(cat <<'EOF'
Add the Satın alımlar section to Profil

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

### Task 10: Whole-branch verification and close

**Files:**
- Read-only: everything under `App/Sources/EnglishApp/Store/`, `App/Tests/EnglishAppTests/Store/`, `docs/store-setup.md`.
- Modify (only where defects are found): any file from Tasks 1-9.

**Interfaces:**
- Consumes: the whole slice.
- Produces: a final green CI run, a spec-acceptance verdict, and the integration decision.

This is a cross-task gate. It looks for what per-task CI cannot see.

- [ ] **Step 1: Mechanical checks**

```bash
grep -rn "DevelopmentPackageAccessProvider" App LearningEngine
grep -rn "unlockAll\|DeveloperOverride" App/Sources | grep -v "#if DEBUG"
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: no `DevelopmentPackageAccessProvider` hits; every `unlockAll`/`DeveloperOverride` use in `App/Sources` sits inside a `#if DEBUG` region (read each hit's surrounding lines to confirm — `Store/StoreAccessProviders.swift`, `AppState.swift`, `ProfileView.swift`); the assembly script leaves `git status` clean (the derived JSON is up to date).

- [ ] **Step 2: Confirm the spec's acceptance criteria one by one**

Record each result in the report:
- package one-time product, premium two subscriptions, ids exactly as in the spec (`grep -rn "com.niinova22.englishapp" App/Sources scripts App/StoreKit docs/store-setup.md` — every id spelled identically everywhere);
- `ContentPackage.storeProductID` populated for YDS and package version 6 (`RealContentSeedingTests`);
- free preview unchanged: the existing `test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked` still passes unmodified;
- package and premium independent (`EntitlementStoreTests`, `AppStateStoreTests`);
- tutor gate: without premium `AppState.loadTutorEngineIfNeeded` returns before loading, `TutorTabView` shows the locked state, both Ask buttons open the premium paywall;
- paywall states cover loading, load failure, purchasing, pending, cancelled, failed, restore, already owned (`PaywallViewModelTests`);
- Release compiles: `App Build`'s unsigned build step succeeded (it builds without `-configuration`, i.e. the project default; if the log shows `Debug`, add a `-configuration Release` build step to `.github/workflows/app-build.yml` in this task so the Release path is compiled on every push).

- [ ] **Step 3: Commit any fixes (skip if none)**

```bash
git add -A App docs scripts
git commit -m "$(cat <<'EOF'
Apply whole-branch review fixes to the StoreKit purchases slice

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 4: Final CI run**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Both must be green at the branch head.

- [ ] **Step 5: Record the known gaps and close**

Report that real purchases, the Apple payment sheet, Ask to Buy, restore and subscription renewal cannot be exercised by CI and stay on the TestFlight checklist in `docs/store-setup.md`, and that App Store Connect setup (spec section 7) is the user's to do. Then use the `superpowers:finishing-a-development-branch` skill to decide how the branch is integrated. Do not merge or push to `master` without that decision.

---

## Self-review

**1. Spec coverage.**

| Spec requirement | Task |
|---|---|
| Products and ids (section 1) | Tasks 3 (`PremiumProducts`), 2 (package id), 5 (`.storekit`, guide), 10 (id consistency check) |
| `PurchaseService` protocol, live wrapper, fake (section 2) | Tasks 3, 5 |
| `EntitlementStore`: start/refresh, cache, snapshot, change notification (section 2) | Task 3 |
| Package and premium providers, DEBUG override, release exclusion (section 2) | Task 4 |
| `storeProductID` in model, importer, assembly, version 6 (section 3) | Tasks 1, 2 |
| Paywall sheet, both modes, state machine, disclosure, legal links (4.1) | Tasks 6, 7 |
| Entry points: locked lesson, Tutor/Ask, Profil (4.2) | Tasks 7, 8, 9 |
| Turkish copy (4.3) | All UI tasks (real Turkish characters) |
| Data flow and edge cases (section 5) | Tasks 3, 6 (purchase/cancel/pending/refund/restore/offline cache), 7 (no store product → no buy button) |
| Testing (section 6) | Tests in Tasks 1-4, 6; `.storekit` file Task 5; known gap Task 10 |
| What the user must do (section 7) | Task 5 `docs/store-setup.md` |

**2. Placeholder scan.** No "TBD"/"TODO"; the one deferred value (`StoreLinks.privacyPolicy`) is an explicit `nil` with a documented rule (link hidden while nil) and a checklist step, not an unfinished code path. The live-service stub in Task 4 is deliberate, complete, and replaced in Task 5 (same type name).

**3. Type consistency.** `PurchaseService` members (`products(for:)`, `purchase(productID:)`, `currentEntitlements()`, `entitlementUpdates`, `restore()`) are identical in Tasks 3, 4 (stub), 5 and the fake. `EntitlementStore.purchase(productID:)`, `.owns(_:)`, `.products(for:)`, `.restore()` match their use in `PaywallViewModel`. `PackageProduct(packageID:productID:name:)` matches `registerPackageProducts` and `PaywallTarget`. `PaywallMode.package(productID:packageName:)` matches its uses in Tasks 6-9. `AppState.tutorAccess`/`TutorAccess.resolve(isTutorAvailable:isPremium:)` match Tasks 4 and 8. `StoreProduct.yds/.monthly/.yearly` are defined once (Task 3 test double) and used in Task 6 tests.
