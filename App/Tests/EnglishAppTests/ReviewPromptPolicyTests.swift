import XCTest
@testable import EnglishApp

final class ReviewPromptPolicyTests: XCTestCase {
    func test_asksOnlyOnTheDayAMilestoneIsReached_andOnlyOnce() {
        XCTAssertEqual(ReviewPromptPolicy.milestone(forStreak: 7, alreadyPrompted: []), 7)
        XCTAssertNil(ReviewPromptPolicy.milestone(forStreak: 8, alreadyPrompted: []))
        XCTAssertNil(ReviewPromptPolicy.milestone(forStreak: 7, alreadyPrompted: [7]))
        XCTAssertEqual(ReviewPromptPolicy.milestone(forStreak: 30, alreadyPrompted: [7]), 30)
        XCTAssertEqual(ReviewPromptPolicy.milestone(forStreak: 100, alreadyPrompted: [7, 30]), 100)
        XCTAssertNil(ReviewPromptPolicy.milestone(forStreak: 3, alreadyPrompted: []))
    }
}
