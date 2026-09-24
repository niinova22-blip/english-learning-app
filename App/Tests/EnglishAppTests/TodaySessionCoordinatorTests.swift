import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class TodaySessionCoordinatorTests: XCTestCase {
    func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_buildTodaySession_coldStart_isEmpty_becauseNewWordsComeFromLessons() throws {
        let context = try makeInMemoryContext()
        context.insert(SampleContent.ydsStarterPackage())
        try context.save()

        let session = try TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5).buildTodaySession()

        XCTAssertTrue(session.isEmpty)
    }

    func test_buildTodaySession_returnsOnlyDueSeenItems() throws {
        let context = try makeInMemoryContext()
        let package = SampleContent.ydsStarterPackage()
        context.insert(package)
        try context.save()
        let reviewedAt = Date().addingTimeInterval(-3 * 86_400)
        try FSRSStateStore().recordReview(userID: "test-user", itemID: "sample-item-hypothesis", rating: .again, now: reviewedAt, in: context, scheduler: FSRSScheduler())

        let session = try TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5).buildTodaySession()

        XCTAssertEqual(session.map(\.id), ["sample-item-hypothesis"])
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

    func test_buildTodaySession_neverIncludesDuePracticeCards() throws {
        let context = try makeInMemoryContext()
        AppModelContainer.seedRealContentIfNeeded(in: context)
        let past = Date().addingTimeInterval(-3 * 86_400)
        let store = FSRSStateStore()
        try store.recordReview(userID: "test-user", itemID: "yds-practice-card-tenses", rating: .again, now: past, in: context, scheduler: FSRSScheduler())
        try store.recordReview(userID: "test-user", itemID: "yds-vocab1-item-economy", rating: .again, now: past, in: context, scheduler: FSRSScheduler())

        let session = try TodaySessionCoordinator(context: context, userID: "test-user", sessionSize: 5).buildTodaySession()

        XCTAssertEqual(session.map(\.id), ["yds-vocab1-item-economy"])
    }
}
