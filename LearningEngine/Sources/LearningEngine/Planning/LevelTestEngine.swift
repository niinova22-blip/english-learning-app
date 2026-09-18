import Foundation

/// SwiftData-free snapshot of one vocabulary item, as fed to the level test.
public struct LevelTestCandidate: Sendable, Equatable {
    public let itemID: String
    public let headword: String
    public let translationTR: String
    public let baseDifficulty: Double

    public init(itemID: String, headword: String, translationTR: String, baseDifficulty: Double) {
        self.itemID = itemID
        self.headword = headword
        self.translationTR = translationTR
        self.baseDifficulty = baseDifficulty
    }
}

public struct LevelTestQuestion: Sendable, Equatable {
    public let itemID: String
    public let headword: String
    /// Four Turkish meanings; exactly one (`choices[correctIndex]`) is correct.
    public let choices: [String]
    public let correctIndex: Int
    public let difficulty: Double
}

public struct LevelTestOutcome: Sendable, Equatable {
    public let cefrLevel: CEFRLevel
    public let vocabularyScore: Double
}

/// A single adaptive-staircase level test administration over a fixed
/// candidate pool. Pure value type — no SwiftData, no clock reads, no
/// hidden randomness (the caller threads an RNG through every call so runs
/// are reproducible in tests).
///
/// Distractors for one question may reappear as the *target* headword of a
/// later question, or vice versa — only the specific item asked as the
/// question's target headword is guaranteed not to repeat as a target
/// within one administration.
public struct LevelTestEngine: Sendable {
    public static let questionCount = 12

    /// One step per question, applied to move the *next* question's target
    /// difficulty after this question's result. Shrinks every 3 questions
    /// for coarse-to-fine convergence.
    private static let stepSizes: [Double] = [
        0.15, 0.15, 0.15, 0.08, 0.08, 0.08, 0.04, 0.04, 0.04, 0.02, 0.02, 0.02
    ]

    /// Fixed thresholds over the YDS package's observed baseDifficulty range
    /// (0.15-0.6, median ~0.3) — see the design spec.
    private static let cefrThresholds: [(max: Double, level: CEFRLevel)] = [
        (0.27, .a2), (0.37, .b1), (0.48, .b2), (.infinity, .c1)
    ]

    public static func cefrLevel(forDifficulty difficulty: Double) -> CEFRLevel {
        cefrThresholds.first { difficulty <= $0.max }?.level ?? .c1
    }

    private var remaining: [LevelTestCandidate]
    private var targetDifficulty: Double
    private var questionIndex = 0
    private var correctCount = 0
    private var lastDifficultyServed: Double

    public private(set) var currentQuestion: LevelTestQuestion?

    /// - Precondition: `candidates.count >= LevelTestEngine.questionCount`.
    ///   Callers must check this themselves (e.g. `LevelTestViewModel.isReady`)
    ///   before constructing a session.
    public init<RNG: RandomNumberGenerator>(candidates: [LevelTestCandidate], using rng: inout RNG) {
        precondition(candidates.count >= Self.questionCount, "LevelTestEngine needs at least \(Self.questionCount) candidates, got \(candidates.count)")
        self.remaining = candidates
        let sortedDifficulties = candidates.map(\.baseDifficulty).sorted()
        self.targetDifficulty = sortedDifficulties[sortedDifficulties.count / 2]
        self.lastDifficultyServed = targetDifficulty
        advance(using: &rng)
    }

    public var isComplete: Bool { currentQuestion == nil }

    /// Records the answer for `currentQuestion`, advances to the next
    /// question (or completes the session), and returns whether it was
    /// correct. A no-op returning `false` once the session is complete.
    @discardableResult
    public mutating func answer<RNG: RandomNumberGenerator>(selectedIndex: Int, using rng: inout RNG) -> Bool {
        guard let question = currentQuestion else { return false }
        let isCorrect = selectedIndex == question.correctIndex
        if isCorrect { correctCount += 1 }
        let step = Self.stepSizes[min(questionIndex, Self.stepSizes.count - 1)]
        targetDifficulty += isCorrect ? step : -step
        questionIndex += 1
        advance(using: &rng)
        return isCorrect
    }

    public func outcome() -> LevelTestOutcome {
        LevelTestOutcome(
            cefrLevel: Self.cefrLevel(forDifficulty: lastDifficultyServed),
            vocabularyScore: Double(correctCount) / Double(Self.questionCount)
        )
    }

    private mutating func advance<RNG: RandomNumberGenerator>(using rng: inout RNG) {
        guard questionIndex < Self.questionCount, remaining.count >= 4 else {
            currentQuestion = nil
            return
        }
        let picked = remaining.min { lhs, rhs in
            let dl = abs(lhs.baseDifficulty - targetDifficulty)
            let dr = abs(rhs.baseDifficulty - targetDifficulty)
            if dl != dr { return dl < dr }
            return lhs.itemID < rhs.itemID // deterministic tie-break
        }!
        remaining.removeAll { $0.itemID == picked.itemID }
        lastDifficultyServed = picked.baseDifficulty

        let distractors = remaining.shuffled(using: &rng).prefix(3)
        var options = [picked.translationTR] + distractors.map(\.translationTR)
        options.shuffle(using: &rng)
        let correctIndex = options.firstIndex(of: picked.translationTR)!

        currentQuestion = LevelTestQuestion(
            itemID: picked.itemID, headword: picked.headword,
            choices: options, correctIndex: correctIndex, difficulty: picked.baseDifficulty
        )
    }
}
