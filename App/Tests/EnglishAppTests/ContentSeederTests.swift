import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class ContentSeederTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_emptyStore_imports() throws {
        let context = try makeContext()
        XCTAssertEqual(try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context), .imported)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ContentPackage>()), 1)
    }

    func test_sameVersion_isUpToDate_andDoesNotDuplicate() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)
        XCTAssertEqual(try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context), .upToDate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
    }

    func test_newerVersion_replacesContent_andKeepsUserState() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)
        try FSRSStateStore().recordReview(userID: "u", itemID: "item-u0-l0-i0", rating: .good, now: Date(), in: context, scheduler: FSRSScheduler())
        context.insert(LessonProgress(userID: "u", lessonID: "lesson-u0-l0", startedAt: Date()))
        try context.save()

        let outcome = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 2, titleSuffix: " (v2)"), into: context)

        XCTAssertEqual(outcome, .upgraded(from: 1, to: 2))
        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].version, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
        let lessons = try context.fetch(FetchDescriptor<Lesson>())
        XCTAssertTrue(lessons.allSatisfy { $0.title.hasSuffix(" (v2)") })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LessonProgress>()), 1)
    }

    func test_invalidNewerContent_throws_andKeepsOldContent() throws {
        let context = try makeContext()
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 1), into: context)

        XCTAssertThrowsError(try ContentSeeder.seed(bundledData: TestPackageJSON.invalid, into: context))

        let packages = try context.fetch(FetchDescriptor<ContentPackage>())
        XCTAssertEqual(packages.map(\.version), [1])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearningItem>()), 8)
    }
}
