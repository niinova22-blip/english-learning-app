import XCTest
@testable import LearningEngine

final class PracticeScoringTests: XCTestCase {
    func test_belowFiftyPercent_isAgain() {
        XCTAssertEqual(PracticeScoring.rating(correct: 0, total: 8), .again)
        XCTAssertEqual(PracticeScoring.rating(correct: 3, total: 8), .again)   // 37.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 2, total: 5), .again)   // 40%
    }

    func test_exactlyFiftyPercent_isHard() {
        XCTAssertEqual(PracticeScoring.rating(correct: 4, total: 8), .hard)
        XCTAssertEqual(PracticeScoring.rating(correct: 5, total: 10), .hard)
    }

    func test_betweenFiftyAndSeventyFive_isHard() {
        XCTAssertEqual(PracticeScoring.rating(correct: 5, total: 8), .hard)    // 62.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 7, total: 10), .hard)   // 70%
    }

    func test_exactlySeventyFivePercent_isGood() {
        XCTAssertEqual(PracticeScoring.rating(correct: 6, total: 8), .good)
        XCTAssertEqual(PracticeScoring.rating(correct: 3, total: 4), .good)
    }

    func test_betweenSeventyFiveAndOneHundred_isGood() {
        XCTAssertEqual(PracticeScoring.rating(correct: 7, total: 8), .good)    // 87.5%
        XCTAssertEqual(PracticeScoring.rating(correct: 9, total: 10), .good)
    }

    func test_allCorrect_isEasy() {
        XCTAssertEqual(PracticeScoring.rating(correct: 8, total: 8), .easy)
        XCTAssertEqual(PracticeScoring.rating(correct: 1, total: 1), .easy)
    }

    func test_emptySession_isAgain_andNeverDividesByZero() {
        XCTAssertEqual(PracticeScoring.rating(correct: 0, total: 0), .again)
    }

    func test_selectionSize_isEightForGrammarAndFiveOtherwise_cappedByThePool() {
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 20, skill: .grammar), 8)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 20, skill: .reading), 5)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 3, skill: .grammar), 3)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 2, skill: .reading), 2)
        XCTAssertEqual(PracticeScoring.selectionSize(poolCount: 0, skill: .grammar), 0)
    }
}
