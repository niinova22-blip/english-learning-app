# Slice 8: StoreKit 2 Purchases, Entitlements and Paywall — Design Spec

Date: 2026-09-20

## Context

Slice 6a introduced the entitlement boundary: `PackageAccessProvider` returns
`.owned` or `.preview` per package, `LessonAccessPolicy` exposes only the
lowest-ordered unit of a preview package, and a development provider (the
Profile toggle "Tüm paketleri aç") stands in for real purchases. Slice 7
finished the YDS content: the package now holds 9 units, 49 lessons and 335
questions, of which the first unit (3 vocabulary + 7 practice lessons) is the
free preview.

Slice 8 replaces the development provider with StoreKit 2 and adds the AI
Premium layer. Screens keep talking to the same protocol; only the
implementation behind it changes, plus a paywall and the AI gate.

Standing product direction (memory: goal-packages direction): packages are sold
individually; a separate subscription unlocks the AI features; the two are
independent of each other. Everything stays on device — no server.

## Product decisions (user-approved, 2026-09-20)

1. **Package = one-time purchase** (non-consumable). One product per package.
2. **AI Premium = auto-renewing subscription**, one subscription group with a
   monthly and a yearly product. Independent of any package.
3. **Free preview stays as built:** first unit free, every other unit locked.
   (The 7a practice lessons living in the free unit is accepted.)
4. **AI gate: visible but locked.** The Tutor tab and every "Öğretmene Sor"
   button stay visible; without premium, tapping opens the premium paywall.
5. **Architecture: native StoreKit 2 with the package → product mapping stored
   in content data** (rejected: mapping hard-coded in app code; RevenueCat).
   Adding a package later is content work only.

## Non-goals

- Any server, server-side receipt validation, or account system.
- Offer codes, promotional or introductory-offer UI, price experiments.
- Products for future packages (TOEFL, Business, Travel).
- The AI study coach (Slice 9). Slice 8 only gates the features that exist.
- Family Sharing. Products ship with Family Sharing off.
- Prices in code. Prices live in App Store Connect; the app shows
  `Product.displayPrice`.

## 1. Products

| Product | Type | Product ID |
|---|---|---|
| YDS package | non-consumable | `com.niinova22.englishapp.package.yds` |
| AI Premium monthly | auto-renewable subscription | `com.niinova22.englishapp.premium.monthly` |
| AI Premium yearly | auto-renewable subscription | `com.niinova22.englishapp.premium.yearly` |

The two subscriptions share the subscription group `ai_premium`. The bundle id
prefix matches `App/project.yml`. IDs are contractual: they are created once in
App Store Connect and cannot be reused after deletion.

The package product id lives in the package content JSON (see section 3); the
two premium ids are app constants (`PremiumProducts`), because premium is not a
content package.

## 2. Architecture

All new app code lives under `App/Sources/EnglishApp/Store/`. The LearningEngine
package gets no StoreKit dependency: its `PackageAccessLevel` and
`LessonAccessPolicy` stay untouched.

```swift
/// Everything StoreKit does, behind a protocol so the entitlement logic is
/// testable with a fake.
protocol PurchaseService: Sendable {
    func products(for ids: [String]) async throws -> [StoreProduct]
    func purchase(productID: String) async throws -> PurchaseOutcome
    func currentEntitlements() async -> [StoreEntitlement]
    var entitlementUpdates: AsyncStream<StoreEntitlement> { get }
    func restore() async throws
}

struct StoreProduct: Equatable, Sendable {
    let id: String
    let displayName: String
    let displayPrice: String
    let kind: Kind            // .package, .premiumMonthly, .premiumYearly
}

enum PurchaseOutcome: Equatable, Sendable { case purchased, pending, cancelled }

struct StoreEntitlement: Equatable, Sendable {
    let productID: String
    let isActive: Bool        // false after revocation, refund or expiry
}
```

- `StoreKitPurchaseService` (live) wraps `Product.products(for:)`,
  `Product.purchase()`, `Transaction.currentEntitlements`,
  `Transaction.updates` and `AppStore.sync()`. Only `.verified` transactions
  produce entitlements; `.unverified` results are dropped. `transaction.finish()`
  is called right after a verified transaction is handed to the store;
  `currentEntitlements` keeps reporting finished non-consumable and active
  subscription transactions, so finishing early cannot lose access.
- `FakePurchaseService` (tests) is scriptable: fixed products, a queue of
  purchase outcomes, injectable entitlement updates and failures.
- `EntitlementStore` (`@MainActor @Observable`) is the single source of truth:
  - `ownedProductIDs: Set<String>` and `isPremium: Bool` (any active premium
    product).
  - `start()` reads `currentEntitlements()` once, then consumes
    `entitlementUpdates` for the app's lifetime.
  - Persists the last known active product ids to `UserDefaults` and restores
    them at init, so an offline cold start does not re-lock a purchased
    package. A live `currentEntitlements()` result always replaces the cache.
  - Bumps `AppState.dataGeneration` whenever the entitled set changes, which the
    existing screens already use to reload (Bugün, Ders Yolu, Profil).
  - Mirrors the active product ids into an `EntitlementSnapshot` (a small
    lock-protected `Sendable` object), because `PackageAccessProvider` is a
    synchronous, non-main-actor protocol that the planners call from anywhere.
    UI observes the store; providers read the snapshot. The snapshot also holds
    the package id → `storeProductID` / name table, filled once from the
    installed `ContentPackage` rows at launch.
- `StoreKitPackageAccessProvider: PackageAccessProvider` maps a package id to
  its `storeProductID` (read from `ContentPackage`) and returns `.owned` when
  that product is in `ownedProductIDs`, `.preview` otherwise. A package with no
  `storeProductID` is always `.preview`.
- `PremiumAccessProvider` (protocol: `var isPremium: Bool { get }`) is
  implemented by `EntitlementStore`. Tutor code depends on the protocol only.
- `AppState` owns the `EntitlementStore` and builds both providers from it. In
  `DEBUG` builds the existing developer toggle overrides both providers to
  owned/premium; in release builds the toggle and `DevelopmentPackageAccessProvider`
  are not compiled in.

## 3. Content changes

- `ContentPackage` gains `public var storeProductID: String?` (default `nil`).
  SwiftData lightweight migration handles a new optional attribute; no manual
  migration is written.
- The content JSON document header gains an optional `"storeProductID"` string.
  `ContentImporter` reads it and validates: when present it must be non-empty.
  Documents without it keep importing (existing tests and fixtures).
- `scripts/assemble-content.py` stamps
  `"storeProductID": "com.niinova22.englishapp.package.yds"` on the YDS package
  and `PACKAGE_VERSION` becomes **6**, so `ContentSeeder` re-imports installed
  packages and the new attribute is populated. Existing ids are unchanged, so
  FSRS history survives the reseed (the same mechanism as versions 4 and 5).
- The derived JSON files are regenerated, never hand-edited.

## 4. Screens

### 4.1 Paywall sheet

`PaywallView` with two modes: `.package(packageID)` and `.premium`.

- **Package mode:** package name, a short list of what is included (units and
  lesson counts read from the package outline), the localized price, a primary
  "Satın al" button, and "Satın alımları geri yükle".
- **Premium mode:** benefit list (Öğretmene Sor, sohbet, çalışma koçu yakında),
  the monthly and yearly options as a segmented choice with their localized
  prices, "Abone ol", and "Satın alımları geri yükle". Below the button: the
  auto-renewal disclosure, and links to the terms of use and privacy policy
  (both required by App Review for subscriptions). Links open URLs kept in one
  constant file, set by the user before release.
- **State machine (`PaywallViewModel`):** `loadingProducts` → `ready` |
  `loadFailed(retry)`; `purchasing`; `pending` ("Onay bekleniyor" — Ask to
  Buy); `succeeded` (sheet dismisses); `failed(message, retry)`. A cancelled
  purchase returns silently to `ready`. `alreadyOwned` is shown when the
  entitlement already exists.
- The purchase button is disabled while `purchasing`. The view model never
  mutates entitlements itself: it asks `PurchaseService`, and success arrives
  through `EntitlementStore`.

### 4.2 Entry points

- **Locked lesson sheet** (Ders Yolu and Bugün): the existing "Bu ders paketin
  tam sürümünde" sheet gains a "Paketi aç" button that opens the package
  paywall.
- **Tutor tab and "Öğretmene Sor" buttons** (study card feedback, practice
  feedback): when `isPremium` is false, the tab shows a locked state with an
  "AI Premium'a geç" button, and each Ask button opens the premium paywall
  instead of the tutor. No tutor model is loaded while the user is not premium.
- **Profil → "Satın alımlar":** package status (Açık / Önizleme), premium status
  and renewal date when subscribed, "Satın alımları geri yükle", and "Aboneliği
  yönet" (`AppStore.showManageSubscriptions`).

### 4.3 Copy

All learner-facing strings are Turkish, informal register, consistent with the
existing screens and `Localizable.xcstrings`.

## 5. Data flow and edge cases

- **Launch:** `EntitlementStore` restores the cached ids, then `start()`
  refreshes from StoreKit and listens for updates. Screens render from the
  cache immediately.
- **Purchase:** paywall → `EntitlementStore.purchase` → `PurchaseService.purchase`
  → `.purchased` → the store re-reads `currentEntitlements()` (StoreKit does not
  emit in-app purchases on `Transaction.updates`; that stream carries purchases
  made elsewhere, Ask-to-Buy approvals, renewals and refunds) → store updates →
  `dataGeneration` bumps → locked screens reload → paywall dismisses.
- **Cancelled:** no message, no state change. **Pending (Ask to Buy):** the
  paywall shows the waiting state; approval later arrives through
  `Transaction.updates` even if the app was relaunched.
- **Refund / revoke / expiry:** an update with `isActive == false` removes the
  product; a package that was owned falls back to preview, premium turns off.
  Lessons already in progress stay in the database (progress is never deleted);
  they are simply not offered while locked.
- **Restore:** `AppStore.sync()` then a fresh `currentEntitlements()` read.
- **Products fail to load** (offline, product not yet approved): the paywall
  shows "Fiyatlar yüklenemedi" with a retry; owned status still works from the
  cache.
- **Unverified transaction:** ignored, never grants access, never finished.
- **Package without `storeProductID`:** stays preview; the locked sheet shows
  no purchase button.

## 6. Testing

CI is the only place tests run (no Swift toolchain on the development machine);
`Swift Tests` covers LearningEngine, `App Build` runs the App target's tests.

- **LearningEngine (`Swift Tests`):** `ContentImporter` reads and validates
  `storeProductID` (present, absent, empty rejected); the real package fixture
  carries the YDS product id and version 6.
- **App tests (`App Build`), with `FakePurchaseService`:**
  - `EntitlementStore`: purchase grants the package; premium product grants
    `isPremium`; package and premium are independent; revocation and expiry
    remove access; the cached state survives an offline start and is replaced
    by a live read; unverified results are ignored; a change bumps
    `dataGeneration`.
  - `StoreKitPackageAccessProvider`: owned vs preview, missing
    `storeProductID`, unknown package id.
  - `PaywallViewModel`: every state transition, including cancel, pending, load
    failure with retry, and double-tap protection.
  - Gating: without premium the Ask button and Tutor tab do not load the tutor
    engine; with premium they behave as today.
  - Regression: every existing test that uses `FixedAccessProvider` is
    unchanged; the DEBUG override still unlocks everything.
- **A `.storekit` configuration file** with the three products is checked in for
  local Xcode runs and sandbox-style development.
- **Known gap, recorded for the TestFlight checklist:** real purchases, the
  Apple sheet, Ask to Buy, restore and subscription renewal cannot be exercised
  by CI. They are verified once on a device with a sandbox tester account.

## 7. What the user must do outside the code

1. Accept the Paid Applications agreement and complete tax and banking details
   in App Store Connect.
2. Create the three products with the exact ids in section 1, set prices, add
   Turkish display names and descriptions, and attach a review screenshot of
   the paywall.
3. Provide the privacy policy URL and the terms of use URL (subscription apps
   are rejected without them).
4. Create a sandbox tester account for TestFlight verification.

## 8. Risks

- **SwiftData model change is not runnable locally.** The added optional
  attribute is the lowest-risk kind of change; CI (`App Build` tests seeding
  from the real package) is the gate, and the reseed path is already proven by
  versions 4 and 5.
- **StoreKit behaviour cannot be executed in CI.** Mitigated by the protocol
  boundary (all decision logic is tested against the fake) and by keeping
  `StoreKitPurchaseService` a thin wrapper with no logic of its own.
- **App Review:** subscriptions need the disclosure text, terms and privacy
  links, and a working restore button; all three are in section 4.1.
