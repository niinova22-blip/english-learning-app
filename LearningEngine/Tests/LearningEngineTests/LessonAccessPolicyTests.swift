import XCTest
@testable import LearningEngine

final class LessonAccessPolicyTests: XCTestCase {
    // Units deliberately out of array order: access is decided by `order`.
    let outline = PackageOutline(units: [
        UnitOutline(id: "u-second", order: 1, lessonIDs: ["b1", "b2"]),
        UnitOutline(id: "u-first", order: 0, lessonIDs: ["a1", "a2", "a3"]),
    ])

    func test_preview_onlyLowestOrderUnitIsAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: outline, level: .preview), ["a1", "a2", "a3"])
    }

    func test_owned_everyLessonIsAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: outline, level: .owned), ["a1", "a2", "a3", "b1", "b2"])
    }

    func test_preview_emptyPackage_hasNothingAccessible() {
        XCTAssertEqual(LessonAccessPolicy().accessibleLessonIDs(in: PackageOutline(units: []), level: .preview), [])
    }
}
