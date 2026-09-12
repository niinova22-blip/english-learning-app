import XCTest
@testable import LearningEngine

final class PackageSmokeTests: XCTestCase {
    func test_learningEngineVersion_isNotEmpty() {
        XCTAssertFalse(learningEngineVersion.isEmpty)
    }
}
