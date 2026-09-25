import XCTest
@testable import EnglishApp
import LearningEngine

final class DesignSystemTests: XCTestCase {
    func test_rgb_parsesHex() {
        let c = Theme.rgb(0x0F766E)
        XCTAssertEqual(c.r, 15.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.g, 118.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.b, 110.0 / 255, accuracy: 1e-9)
    }

    func test_skillDisplayNames_areEnglish() {
        XCTAssertEqual(Skill.allCases.map(\.displayName),
                       ["Vocabulary", "Grammar", "Reading", "Listening", "Writing", "Speaking", "Pronunciation"])
    }

    func test_ratingLabels() {
        XCTAssertEqual([FSRSRating.again, .hard, .good, .easy].map(\.label),
                       ["Forgot", "Hard", "Knew it", "Easy"])
    }

    func test_planTaskText() {
        XCTAssertEqual(PlanTaskText.title(.review(cardCount: 14, minutes: 5.6, isDone: false)), "Word review")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: false)), "14 cards · 6 min")
        XCTAssertEqual(PlanTaskText.subtitle(.review(cardCount: 14, minutes: 5.6, isDone: true)), "14 cards · done")
        XCTAssertEqual(PlanTaskText.title(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "Science · 2")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "Science · 2", skill: .vocabulary, minutes: 8, isDone: false)), "New lesson · Vocabulary · 8 min")
        XCTAssertEqual(PlanTaskText.subtitle(.lesson(id: "l", title: "x", skill: .grammar, minutes: 10, isDone: true)), "Grammar · done")
        XCTAssertEqual(PlanTaskText.title(.locked(id: "l", title: "Law · 1")), "Law · 1")
        XCTAssertEqual(PlanTaskText.subtitle(.locked(id: "l", title: "Law · 1")), "Unlock package")
    }

    func test_minutes_roundUp() {
        XCTAssertEqual(PlanTaskText.minutes(0.4), 1)
        XCTAssertEqual(PlanTaskText.minutes(8), 8)
        XCTAssertEqual(PlanTaskText.minutes(21.2), 22)
    }
}
