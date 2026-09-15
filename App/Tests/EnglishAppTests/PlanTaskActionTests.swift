import XCTest
@testable import EnglishApp
import LearningEngine

final class PlanTaskActionTests: XCTestCase {
    func test_actions() {
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: false)), .startReview(cardCount: 12))
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: false)), .startLesson(id: "l1"))
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "g1", title: "Tenses II", skill: .grammar, minutes: 10, isDone: false)), .comingSoon(title: "Tenses II"))
        XCTAssertEqual(PlanTaskAction.action(for: .locked(id: "x", title: "Law · 1")), .locked(title: "Law · 1"))
    }
}
