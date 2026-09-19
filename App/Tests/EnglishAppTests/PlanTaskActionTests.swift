import XCTest
@testable import EnglishApp
import LearningEngine

final class PlanTaskActionTests: XCTestCase {
    func test_actions() {
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: false)), .startReview(cardCount: 12))
        XCTAssertEqual(PlanTaskAction.action(for: .review(cardCount: 12, minutes: 4.8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: false)), .startLesson(id: "l1"))
        XCTAssertEqual(PlanTaskAction.action(for: .lesson(id: "l1", title: "T", skill: .vocabulary, minutes: 8, isDone: true)), .none)
        XCTAssertEqual(PlanTaskAction.action(for: .locked(id: "x", title: "Law · 1")), .locked(title: "Law · 1"))
    }

    func test_lessonsWithShippedPracticeContent_openThePracticeSession() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "g1", title: "Zamanlar (Tenses)", skill: .grammar, minutes: 8, isDone: false)),
            .startPractice(lessonID: "g1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "r1", title: "Okuma", skill: .reading, minutes: 10, isDone: false)),
            .startPractice(lessonID: "r1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "r1", title: "Okuma", skill: .reading, minutes: 10, isDone: true)),
            .none
        )
    }

    func test_skillsWithoutContent_stillShowComingSoon() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "d1", title: "Dinleme 1", skill: .listening, minutes: 8, isDone: false)),
            .comingSoon(title: "Dinleme 1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .lesson(id: "w1", title: "Yazma 1", skill: .writing, minutes: 8, isDone: false)),
            .comingSoon(title: "Yazma 1")
        )
    }

    func test_practiceReviewRouting() {
        XCTAssertEqual(
            PlanTaskAction.action(for: .practiceReview(itemID: "i1", lessonID: "l1", title: "Zamanlar", skill: .grammar, minutes: 3, isDone: false)),
            .startPracticeReview(itemID: "i1", lessonID: "l1")
        )
        XCTAssertEqual(
            PlanTaskAction.action(for: .practiceReview(itemID: "i1", lessonID: "l1", title: "Zamanlar", skill: .grammar, minutes: 3, isDone: true)),
            .none
        )
    }
}
