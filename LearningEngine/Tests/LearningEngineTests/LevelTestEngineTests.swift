import XCTest
@testable import LearningEngine

/// Deterministic RNG (splitmix64-style LCG) so tests are reproducible.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

final class LevelTestEngineTests: XCTestCase {
    func makeCandidates(count: Int = 30) -> [LevelTestCandidate] {
        (0..<count).map { i in
            LevelTestCandidate(
                itemID: "item-\(i)", headword: "word\(i)", meaning: "anlam\(i)",
                baseDifficulty: 0.15 + Double(i) * (0.45 / Double(count - 1))
            )
        }
    }

    func test_correctAnswer_raisesNextQuestionsDifficulty() {
        var rng = SeededRNG(state: 1)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let first = try! XCTUnwrap(engine.currentQuestion)
        engine.answer(selectedIndex: first.correctIndex, using: &rng)
        let second = try! XCTUnwrap(engine.currentQuestion)
        XCTAssertGreaterThan(second.difficulty, first.difficulty)
    }

    func test_incorrectAnswer_lowersNextQuestionsDifficulty() {
        var rng = SeededRNG(state: 1)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let first = try! XCTUnwrap(engine.currentQuestion)
        let wrongIndex = (first.correctIndex + 1) % first.choices.count
        engine.answer(selectedIndex: wrongIndex, using: &rng)
        let second = try! XCTUnwrap(engine.currentQuestion)
        XCTAssertLessThan(second.difficulty, first.difficulty)
    }

    func test_twelveQuestions_noHeadwordRepeatsAsTarget() {
        var rng = SeededRNG(state: 42)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        var askedItemIDs: [String] = []
        while let question = engine.currentQuestion {
            askedItemIDs.append(question.itemID)
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
        XCTAssertEqual(askedItemIDs.count, LevelTestEngine.questionCount)
        XCTAssertEqual(Set(askedItemIDs).count, LevelTestEngine.questionCount)
        XCTAssertTrue(engine.isComplete)
    }

    func test_eachQuestion_hasFourChoicesAndCorrectTranslation() {
        var rng = SeededRNG(state: 7)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        let candidatesByID = Dictionary(uniqueKeysWithValues: makeCandidates().map { ($0.itemID, $0) })
        while let question = engine.currentQuestion {
            XCTAssertEqual(question.choices.count, 4)
            let expected = try! XCTUnwrap(candidatesByID[question.itemID])
            XCTAssertEqual(question.choices[question.correctIndex], expected.meaning)
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
    }

    func test_outcome_vocabularyScore_matchesCorrectFraction() {
        var rng = SeededRNG(state: 3)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        var correctSoFar = 0
        var questionIndex = 0
        while let question = engine.currentQuestion {
            let answerCorrectly = questionIndex % 3 != 0 // wrong on questions 0, 3, 6, 9 → 8 correct of 12
            if answerCorrectly { correctSoFar += 1 }
            let index = answerCorrectly ? question.correctIndex : (question.correctIndex + 1) % question.choices.count
            engine.answer(selectedIndex: index, using: &rng)
            questionIndex += 1
        }
        XCTAssertEqual(engine.outcome().vocabularyScore, Double(correctSoFar) / Double(LevelTestEngine.questionCount), accuracy: 1e-9)
    }

    func test_cefrBucketing_atThresholdBoundaries() {
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.15), .a2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.27), .a2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.28), .b1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.37), .b1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.38), .b2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.48), .b2)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.49), .c1)
        XCTAssertEqual(LevelTestEngine.cefrLevel(forDifficulty: 0.6), .c1)
    }

    func test_answeringAfterCompletion_isANoOpAndDoesNotCrash() {
        var rng = SeededRNG(state: 9)
        var engine = LevelTestEngine(candidates: makeCandidates(), using: &rng)
        while let question = engine.currentQuestion {
            engine.answer(selectedIndex: question.correctIndex, using: &rng)
        }
        XCTAssertFalse(engine.answer(selectedIndex: 0, using: &rng))
        XCTAssertNil(engine.currentQuestion)
    }
}
