import XCTest
import SwiftData
@testable import LearningEngine

final class FSRSStateStoreTests: XCTestCase {
    func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ReviewLog.self, UserItemState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func test_recordReview_createsStateOnFirstReview() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let store = FSRSStateStore()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let state = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: now, in: context, scheduler: FSRSScheduler())

        XCTAssertEqual(state.userID, "u1")
        XCTAssertEqual(state.itemID, "item-1")
        XCTAssertEqual(state.reps, 1)
        XCTAssertEqual(state.stability, 2.3065, accuracy: 1e-4)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.rating, .good)
    }

    func test_recordReview_updatesExistingStateOnSecondReview() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let store = FSRSStateStore()
        let scheduler = FSRSScheduler()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Calendar.current.date(byAdding: .day, value: 2, to: first)!

        _ = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: first, in: context, scheduler: scheduler)
        let updated = try store.recordReview(userID: "u1", itemID: "item-1", rating: .good, now: second, in: context, scheduler: scheduler)

        XCTAssertEqual(updated.reps, 2)
        XCTAssertEqual(updated.stability, 10.964332, accuracy: 1e-3)

        let states = try context.fetch(FetchDescriptor<UserItemState>())
        XCTAssertEqual(states.count, 1, "second review must update the existing state, not create a duplicate")

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.count, 2)
    }
}
