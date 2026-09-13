import Foundation
import TutorEngine

@Observable
final class AppState {
    private(set) var dataGeneration = 0
    private(set) var tutorEngine: (any TutorEngine)?

    func bumpDataGeneration() {
        dataGeneration += 1
    }

    /// Attempts to load the on-device tutor model, if not already
    /// loaded. Leaves `tutorEngine` nil on any failure (missing
    /// resource, unsupported device, load error) — callers must treat
    /// nil as "the feature isn't available right now" and hide its UI
    /// entirely, never show it and then fail per-request.
    func loadTutorEngineIfNeeded() async {
        guard tutorEngine == nil else { return }
        // `App/Sources/EnglishApp/Resources/TutorModel/` has no `type:`
        // override in project.yml's `resources:` entry, so XcodeGen
        // bundles it as a plain group: every file inside, at any nesting
        // depth, is flattened to the bundle root rather than preserved
        // under a `TutorModel/` subdirectory (confirmed via the actual
        // Xcode `CpResource` build log — e.g. `config.json` lands at
        // `EnglishApp.app/config.json`, not `EnglishApp.app/TutorModel/
        // config.json`). So there is no "TutorModel" resource to look up
        // directly. Instead, locate one of the model's own files
        // (`config.json`, present for every model MLX can load) and
        // derive the model directory from its parent — the same
        // "resolve via a known bundled file" approach already used for
        // the single-file `YDSAcademicVocabulary1.json` resource
        // elsewhere in this app.
        guard let configURL = Bundle.main.url(forResource: "config", withExtension: "json") else {
            return
        }
        let modelURL = configURL.deletingLastPathComponent()
        do {
            tutorEngine = try await MLXTutorEngine(modelDirectory: modelURL)
        } catch {
            tutorEngine = nil
        }
    }
}
