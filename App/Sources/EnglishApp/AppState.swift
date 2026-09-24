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
    @ObservationIgnored let coachNoteCache = CoachNoteCache()

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

    /// Fills the package -> store product table from the installed packages.
    /// Call once after content seeding, before the first screen renders.
    func registerPackageProducts(from context: ModelContext) {
        let packages = (try? context.fetch(FetchDescriptor<ContentPackage>())) ?? []
        entitlements.snapshot.registerPackages(packages.compactMap { package in
            package.storeProductID.map { PackageProduct(packageID: package.id, productID: $0, name: package.name) }
        })
    }

    /// Cheap, synchronous check for whether the tutor feature could work on
    /// this device/build — checks bundle resource presence and platform,
    /// without loading the (large) model into memory. Safe to call at
    /// launch/every render; the actual model load only happens in
    /// `loadTutorEngineIfNeeded()`, on first use.
    var isTutorAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return Self.modelDirectoryURL != nil
        #endif
    }

    /// `App/Sources/EnglishApp/Resources/TutorModel/` has its own `type:
    /// folder` entry under project.yml's `sources:` (excluded from the
    /// generic `Sources/EnglishApp` entry so it isn't double-bundled — note
    /// XcodeGen has no `resources:` target property at all; it recursively
    /// classifies non-source files found under `sources:` by extension, so
    /// this needs to live under `sources:` too), so XcodeGen preserves it as
    /// a real folder reference: it's bundled as a `TutorModel/` subdirectory
    /// rather than flattened to the bundle root (confirmed via the actual
    /// Xcode `CpResource` build log — e.g. `config.json` lands at
    /// `EnglishApp.app/TutorModel/config.json`). So the model directory can
    /// be looked up directly by name.
    private static var modelDirectoryURL: URL? {
        Bundle.main.url(forResource: "TutorModel", withExtension: nil)
    }

    /// The model load currently in flight, if any. Shared by every caller
    /// of `loadTutorEngineIfNeeded()` (the Today card button and the Tutor
    /// tab) so at most one `MLXTutorEngine` is ever being constructed —
    /// two concurrent loads would hold two copies of the model weights in
    /// memory and leave the two features on different engines.
    private var tutorLoadTask: Task<Void, Never>?

    /// Attempts to load the on-device tutor model, if not already
    /// loaded. Leaves `tutorEngine` nil on any failure (missing
    /// resource, unsupported device, load error) — callers must treat
    /// nil as "the feature isn't available right now" and never show a
    /// per-request failure for it. If a load is already in flight, this
    /// awaits that same load instead of starting a second one.
    func loadTutorEngineIfNeeded() async {
        guard premiumProvider.isPremium else { return }
        guard tutorEngine == nil else { return }
        #if targetEnvironment(simulator)
        // MLX (via Metal) does not run in the iOS Simulator: the
        // Simulator's Metal device only reports Apple-family-2-level GPU
        // support, which is missing features MLX's kernels require, and
        // this fails as a hard trap (SIGABRT) inside MLX/Metal rather
        // than a catchable Swift error -- the `do/catch` below cannot
        // protect against it. Confirmed by CI: once the resource lookup
        // below started succeeding, every Simulator test run crashed the
        // whole app process ~70s into `MLXTutorEngine.init` (this app is
        // the XCTest host, so a crash here takes the whole suite with
        // it), consistent with mlx-swift's documented Simulator
        // limitation (ml-explore/mlx-swift#36, ml-explore/mlx#2605). So:
        // never even attempt construction on the Simulator, and rely on
        // the real-device path (unverified by this project's CI, per its
        // Global Constraints) for actual on-device testing.
        return
        #else
        if let tutorLoadTask {
            await tutorLoadTask.value
            return
        }
        guard let modelURL = Self.modelDirectoryURL else {
            return
        }
        // The task body inherits this class's MainActor isolation, so it
        // cannot start running before `tutorLoadTask` is assigned below
        // (no `await` in between). It clears `tutorLoadTask` itself when
        // finished — success or failure — so a later retry after a failed
        // load starts a fresh attempt, and a caller that resumes late can
        // never clear a newer attempt's task.
        let task = Task {
            do {
                tutorEngine = try await MLXTutorEngine(modelDirectory: modelURL)
            } catch {
                tutorEngine = nil
            }
            tutorLoadTask = nil
        }
        tutorLoadTask = task
        await task.value
        #endif
    }
}
