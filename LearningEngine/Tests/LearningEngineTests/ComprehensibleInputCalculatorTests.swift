import XCTest
@testable import LearningEngine

final class ComprehensibleInputCalculatorTests: XCTestCase {
    let calculator = ComprehensibleInputCalculator()
    let candidate = LearningItem(id: "candidate", type: .vocabulary, frequencyRank: 3000, baseDifficulty: 0.5)

    func test_fit_returnsTooEasy_whenAccuracyAtOrAbove85Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.85, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .tooEasy)
    }

    func test_fit_returnsOptimal_atExactly70Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.70, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal)
    }

    func test_fit_returnsOptimal_atExactly51Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.51, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal)
    }

    func test_fit_returnsTooHard_atOrBelow50Percent() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0.50, averageReactionTimeMs: 1000)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .tooHard)
    }

    func test_fit_returnsOptimal_forFirstEverItem_withNoHistory() {
        let snapshot = UserLevelSnapshot(knownItemIDs: [], rollingComprehensionAccuracy: 0, averageReactionTimeMs: 0)
        XCTAssertEqual(calculator.fit(of: candidate, for: snapshot), .optimal, "cold start must not fall into 'too hard' just because accuracy defaults to 0")
    }
}
