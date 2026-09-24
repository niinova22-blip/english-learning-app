import XCTest
import SwiftData
@testable import LearningEngine

final class LevelTestResultTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([LevelTestResult.self, LearnerProfile.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_insertAndFetch_roundTripsAllFields() throws {
        let context = try makeContext()
        let completedAt = Date(timeIntervalSince1970: 1_000_000)
        context.insert(LevelTestResult(userID: "u1", cefrLevel: .b2, vocabularyScore: 0.75, completedAt: completedAt))
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<LevelTestResult>()).first)
        XCTAssertEqual(fetched.userID, "u1")
        XCTAssertEqual(fetched.cefrLevel, .b2)
        XCTAssertEqual(fetched.vocabularyScore, 0.75, accuracy: 1e-9)
        XCTAssertEqual(fetched.completedAt, completedAt)
    }

    func test_learnerProfile_onboardingFieldsDefaultToIncomplete() throws {
        let context = try makeContext()
        let profile = LearnerProfile(userID: "u1", activePackageID: "pkg", createdAt: Date())
        context.insert(profile)
        try context.save()

        XCTAssertNil(profile.onboardingCompletedAt)
        XCTAssertFalse(profile.hasSkippedLevelTest)
    }
}
