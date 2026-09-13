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
        guard let modelURL = Bundle.main.url(forResource: "TutorModel", withExtension: nil) else {
            return
        }
        do {
            tutorEngine = try await MLXTutorEngine(modelDirectory: modelURL)
        } catch {
            tutorEngine = nil
        }
    }
}
