import XCTest
@testable import LearningEngine

final class SampleContentTests: XCTestCase {
    func test_ydsStarterPackage_hasWiredHierarchy() {
        let package = SampleContent.ydsStarterPackage()

        XCTAssertEqual(package.goal, .yds)
        XCTAssertFalse(package.units.isEmpty)

        let allItems = package.units.flatMap { $0.lessons.flatMap { $0.items } }
        XCTAssertGreaterThanOrEqual(allItems.count, 15)
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
        XCTAssertTrue(allItems.allSatisfy { $0.lesson != nil })
    }
}
