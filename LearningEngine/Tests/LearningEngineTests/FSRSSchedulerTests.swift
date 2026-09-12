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

    func test_secondReview_ratedGood_afterTwoDays_producesReferenceValues() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: referenceDate)!
        let second = scheduler.review(card: first.card, rating: .good, now: twoDaysLater)
        XCTAssertEqual(second.card.difficulty, 2.111214, accuracy: 1e-4)
        XCTAssertEqual(second.card.stability, 10.964332, accuracy: 1e-3)
        XCTAssertEqual(second.card.reps, 2)
        XCTAssertEqual(second.card.lapses, 0)
    }

    func test_secondReview_ratedAgain_afterTwoDays_producesReferenceValuesAndIncrementsLapses() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let twoDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: referenceDate)!
        let second = scheduler.review(card: first.card, rating: .again, now: twoDaysLater)
        XCTAssertEqual(second.card.difficulty, 7.394503, accuracy: 1e-4)
        XCTAssertEqual(second.card.stability, 0.607580, accuracy: 1e-3)
        XCTAssertEqual(second.card.reps, 2)
        XCTAssertEqual(second.card.lapses, 1)
    }

    func test_retrievability_decreasesAsElapsedTimeIncreases() {
        let first = scheduler.review(card: nil, rating: .good, now: referenceDate)
        let soon = Calendar.current.date(byAdding: .day, value: 1, to: referenceDate)!
        let later = Calendar.current.date(byAdding: .day, value: 10, to: referenceDate)!
        XCTAssertGreaterThan(
            scheduler.retrievability(of: first.card, at: soon),
            scheduler.retrievability(of: first.card, at: later)
        )
    }
}
