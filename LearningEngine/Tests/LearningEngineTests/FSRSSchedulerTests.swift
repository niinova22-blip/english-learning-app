import XCTest
@testable import LearningEngine

final class FSRSSchedulerTests: XCTestCase {
    let scheduler = FSRSScheduler()
    let referenceDate = Date(timeIntervalSince1970: 1_700_000_000) // fixed, arbitrary

    func test_newCard_ratedGood_producesReferenceStabilityAndDifficulty() {
        let result = scheduler.review(card: nil, rating: .good, now: referenceDate)
        XCTAssertEqual(result.card.stability, 2.3065, accuracy: 1e-4)
        XCTAssertEqual(result.card.difficulty, 2.118104, accuracy: 1e-4)
        XCTAssertEqual(result.card.reps, 1)
        XCTAssertEqual(result.card.lapses, 0)
    }

    func test_newCard_ratedAgain_producesReferenceStabilityAndDifficultyAndCountsAsLapse() {
        let result = scheduler.review(card: nil, rating: .again, now: referenceDate)
        XCTAssertEqual(result.card.stability, 0.212, accuracy: 1e-4)
        XCTAssertEqual(result.card.difficulty, 6.4133, accuracy: 1e-4)
        XCTAssertEqual(result.card.reps, 1)
        XCTAssertEqual(result.card.lapses, 1)
    }

    func test_newCard_dueDate_isAfterNow() {
        let result = scheduler.review(card: nil, rating: .good, now: referenceDate)
        XCTAssertGreaterThan(result.dueDate, referenceDate)
    }
}
