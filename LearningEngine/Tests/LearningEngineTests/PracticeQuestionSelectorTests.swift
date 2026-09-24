import XCTest
@testable import LearningEngine

final class PracticeQuestionSelectorTests: XCTestCase {
    let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    func at(_ days: Int) -> Date { epoch.addingTimeInterval(Double(days) * 86_400) }

    func fresh(_ id: String, order: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: nil, lastWasCorrect: nil)
    }

    func wrong(_ id: String, order: Int, day: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: at(day), lastWasCorrect: false)
    }

    func right(_ id: String, order: Int, day: Int) -> QuestionCandidate {
        QuestionCandidate(id: id, order: order, lastAttemptedAt: at(day), lastWasCorrect: true)
    }

    func test_neverAttemptedComeFirst_thenWrong_thenCorrect() {
        let candidates = [right("c", order: 0, day: 5), wrong("b", order: 1, day: 5), fresh("a", order: 2)]
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["a", "b", "c"]
        )
    }

    func test_withinATier_leastRecentlyAttemptedComesFirst() {
        let candidates = [wrong("recent", order: 0, day: 9), wrong("old", order: 1, day: 1), wrong("mid", order: 2, day: 5)]
        var rng = SeededGenerator(seed: 1)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["old", "mid", "recent"]
        )
    }

    func test_neverAttemptedTier_keepsAuthoredOrder() {
        let candidates = [fresh("q3", order: 2), fresh("q1", order: 0), fresh("q2", order: 1)]
        var rng = SeededGenerator(seed: 99)
        XCTAssertEqual(
            PracticeQuestionSelector.select(from: candidates, size: 3, using: &rng),
            ["q1", "q2", "q3"]
        )
    }

    func test_sameSeedProducesTheSameSelection_andDifferentSeedsMayDiffer() {
        // Six candidates attempted at the SAME instant with the same outcome:
        // every tie-break but the RNG is exhausted.
        let candidates = (0..<6).map { QuestionCandidate(id: "q\($0)", order: $0, lastAttemptedAt: at(3), lastWasCorrect: true) }
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let first = PracticeQuestionSelector.select(from: candidates, size: 3, using: &a)
        let second = PracticeQuestionSelector.select(from: candidates, size: 3, using: &b)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, 3)
        XCTAssertTrue(first.allSatisfy { candidates.map(\.id).contains($0) })
    }

    func test_poolSmallerThanTheRequestedSize_returnsEverything() {
        let candidates = [fresh("a", order: 0), fresh("b", order: 1)]
        var rng = SeededGenerator(seed: 7)
        XCTAssertEqual(PracticeQuestionSelector.select(from: candidates, size: 8, using: &rng), ["a", "b"])
    }

    func test_emptyPool_returnsEmpty() {
        var rng = SeededGenerator(seed: 7)
        XCTAssertEqual(PracticeQuestionSelector.select(from: [], size: 5, using: &rng), [])
    }

    func test_selectionRespectsTheRequestedSize() {
        let candidates = (0..<12).map { fresh("q\($0)", order: $0) }
        var rng = SeededGenerator(seed: 3)
        XCTAssertEqual(PracticeQuestionSelector.select(from: candidates, size: 5, using: &rng).count, 5)
    }

    func test_seededGenerator_isDeterministicAndNotConstant() {
        var a = SeededGenerator(seed: 12345)
        var b = SeededGenerator(seed: 12345)
        let first = (0..<4).map { _ in a.next() }
        let second = (0..<4).map { _ in b.next() }
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, 4, "generator must not repeat itself immediately")
    }
}
