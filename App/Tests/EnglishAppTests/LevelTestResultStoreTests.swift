import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

final class LevelTestResultStoreTests: XCTestCase {
    let userID = "u"
    let t1 = Date(timeIntervalSince1970: 1_800_000_000)
    let t2 = Date(timeIntervalSince1970: 1_800_100_000)

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_save_insertsWhenAbsent() throws {
        let context = try makeContext()
        try LevelTestResultStore.save(LevelTestOutcome(cefrLevel: .b1, vocabularyScore: 0.5), in: context, userID: userID, now: t1)
        let results = try context.fetch(FetchDescriptor<LevelTestResult>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].userID, userID)
        XCTAssertEqual(results[0].cefrLevel, .b1)
        XCTAssertEqual(results[0].vocabularyScore, 0.5, accuracy: 1e-9)
        XCTAssertEqual(results[0].completedAt, t1)
    }

    func test_save_overwritesWhenPresent() throws {
        let context = try makeContext()
        try LevelTestResultStore.save(LevelTestOutcome(cefrLevel: .b1, vocabularyScore: 0.5), in: context, userID: userID, now: t1)
        try LevelTestResultStore.save(LevelTestOutcome(cefrLevel: .c1, vocabularyScore: 0.9), in: context, userID: userID, now: t2)
        let results = try context.fetch(FetchDescriptor<LevelTestResult>())
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].cefrLevel, .c1)
        XCTAssertEqual(results[0].vocabularyScore, 0.9, accuracy: 1e-9)
        XCTAssertEqual(results[0].completedAt, t2)
    }

    func test_save_clearsSkippedFlagOnExistingProfile() throws {
        let context = try makeContext()
        context.insert(LearnerProfile(userID: userID, activePackageID: "pkg", createdAt: t1, onboardingCompletedAt: t1, hasSkippedLevelTest: true))
        try context.save()
        try LevelTestResultStore.save(LevelTestOutcome(cefrLevel: .b2, vocabularyScore: 0.7), in: context, userID: userID, now: t2)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertFalse(profile.hasSkippedLevelTest)
    }

    func test_save_withoutProfile_doesNotCreateOne() throws {
        let context = try makeContext()
        try LevelTestResultStore.save(LevelTestOutcome(cefrLevel: .b2, vocabularyScore: 0.7), in: context, userID: userID, now: t2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearnerProfile>()), 0)
    }
}
