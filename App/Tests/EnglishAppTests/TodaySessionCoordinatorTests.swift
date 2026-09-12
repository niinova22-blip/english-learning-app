import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class TodaySessionCoordinatorTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_buildTodaySession_coldStart_returnsNonEmptySessionCappedAtSize() throws {
        let context = try makeInMemoryContext()
        let package = SampleContent.ydsStarterPackage()
        context.insert(package)
        try context.save()

        let coordinator = TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5)
        let session = try coordinator.buildTodaySession()

        XCTAssertFalse(session.isEmpty)
        XCTAssertLessThanOrEqual(session.count, 5)
    }

    func test_computeSnapshot_noHistory_isColdStart() throws {
        let context = try makeInMemoryContext()
        let coordinator = TodaySessionCoordinator(context: context, userID: "test-user")
        let snapshot = try coordinator.computeSnapshot()
        XCTAssertTrue(snapshot.isColdStart)
    }

    func test_computeSnapshot_withHistory_computesRollingAccuracy() throws {
        let context = try makeInMemoryContext()
        let now = Date()
        for i in 0..<10 {
            let rating: FSRSRating = i < 7 ? .good : .again
            let log = ReviewLog(userID: "test-user", itemID: "item-\(i)", rating: rating, reviewedAt: now.addingTimeInterval(Double(-i) * 60))
            context.insert(log)
        }
        try context.save()

        let coordinator = TodaySessionCoordinator(context: context, userID: "test-user")
        let snapshot = try coordinator.computeSnapshot()

        XCTAssertEqual(snapshot.rollingComprehensionAccuracy, 0.7, accuracy: 1e-9)
        XCTAssertFalse(snapshot.isColdStart)
    }
}
