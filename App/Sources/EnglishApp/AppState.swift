import Foundation
import TutorEngine

@MainActor
@Observable
final class AppState {
    private(set) var dataGeneration = 0
    private(set) var tutorEngine: (any TutorEngine)?

    func bumpDataGeneration() {
        dataGeneration += 1
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
    /// folder` entry in project.yml's `resources:` (excluded from the
    /// generic `Resources` group entry so it isn't double-bundled), so
    /// XcodeGen preserves it as a real folder reference: it's bundled as a
    /// `TutorModel/` subdirectory rather than flattened to the bundle root
    /// (confirmed via the actual Xcode `CpResource` build log — e.g.
    /// `config.json` lands at `EnglishApp.app/TutorModel/config.json`).
    /// So the model directory can be looked up directly by name.
    private static var modelDirectoryURL: URL? {
        Bundle.main.url(forResource: "TutorModel", withExtension: nil)
    }

    /// Attempts to load the on-device tutor model, if not already
    /// loaded. Leaves `tutorEngine` nil on any failure (missing
    /// resource, unsupported device, load error) — callers must treat
    /// nil as "the feature isn't available right now" and hide its UI
    /// entirely, never show it and then fail per-request.
    func loadTutorEngineIfNeeded() async {
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
        guard let modelURL = Self.modelDirectoryURL else {
            return
        }
        do {
            tutorEngine = try await MLXTutorEngine(modelDirectory: modelURL)
        } catch {
            tutorEngine = nil
        }
        #endif
    }
}
