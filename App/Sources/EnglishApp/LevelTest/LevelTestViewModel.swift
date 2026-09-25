import Foundation
import Observation
import SwiftData
import LearningEngine

/// Reads the active package's vocabulary items as level-test candidates.
/// Non-vocabulary items (grammarPoint/phrase/collocation) never appear —
/// the level test is vocabulary-only; practice questions are graded in the
/// practice session, not here.
enum LevelTestCandidateFetcher {
    static func fetch(packageID: String, in context: ModelContext) -> [LevelTestCandidate] {
        let items = (try? context.fetch(FetchDescriptor<LearningItem>())) ?? []
        return items
            .filter { $0.type == .vocabulary && $0.lesson?.unit?.package?.id == packageID }
            .compactMap { item -> LevelTestCandidate? in
                guard let content = item.content else { return nil }
                return LevelTestCandidate(itemID: item.id, headword: content.headword, meaning: content.translationTR.isEmpty ? content.definition : content.translationTR, baseDifficulty: item.baseDifficulty)
            }
    }
}

/// Drives one `LevelTestEngine` session for SwiftUI. Used both by onboarding
/// (Task 4) and by the Profil "retake" entry point (Task 8) — it knows
/// nothing about either caller's surrounding flow.
@MainActor
@Observable
final class LevelTestViewModel {
    let isReady: Bool
    private(set) var currentQuestion: LevelTestQuestion?
    private(set) var questionNumber = 0
    private(set) var outcome: LevelTestOutcome?

    private let candidates: [LevelTestCandidate]
    private var engine: LevelTestEngine?
    private var rng = SystemRandomNumberGenerator()

    init(candidates: [LevelTestCandidate]) {
        self.candidates = candidates
        self.isReady = candidates.count >= LevelTestEngine.minimumCandidates
    }

    func start() {
        guard isReady, engine == nil else { return }
        var localRNG = rng
        let newEngine = LevelTestEngine(candidates: candidates, using: &localRNG)
        rng = localRNG
        engine = newEngine
        currentQuestion = newEngine.currentQuestion
        questionNumber = 1
        outcome = nil
    }

    func answer(selectedIndex: Int) {
        guard var engine else { return }
        var localRNG = rng
        engine.answer(selectedIndex: selectedIndex, using: &localRNG)
        rng = localRNG
        self.engine = engine
        if engine.isComplete {
            outcome = engine.outcome()
            currentQuestion = nil
        } else {
            currentQuestion = engine.currentQuestion
            questionNumber += 1
        }
    }
}
