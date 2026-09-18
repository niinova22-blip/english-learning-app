import XCTest
import SwiftData
@testable import LearningEngine

final class LearnerModelsTests: XCTestCase {
    func makeContext() throws -> ModelContext {
        let schema = Schema([LearnerProfile.self, LessonProgress.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    func test_learnerProfile_defaults() throws {
        let context = try makeContext()
        let created = Date(timeIntervalSince1970: 1_000)
        context.insert(LearnerProfile(userID: "u1", activePackageID: "p1", createdAt: created))
        try context.save()

        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 20)
        XCTAssertNil(profile.examDate)
        XCTAssertEqual(profile.activePackageID, "p1")
        XCTAssertEqual(profile.createdAt, created)
    }

    func test_lessonProgress_idCombinesUserAndLesson_andStartsIncomplete() throws {
        let context = try makeContext()
        let started = Date(timeIntervalSince1970: 2_000)
        context.insert(LessonProgress(userID: "u1", lessonID: "l1", startedAt: started))
        try context.save()

        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>()).first)
        XCTAssertEqual(progress.id, "u1|l1")
        XCTAssertEqual(LessonProgress.makeID(userID: "u1", lessonID: "l1"), "u1|l1")
        XCTAssertEqual(progress.startedAt, started)
        XCTAssertNil(progress.completedAt)
    }
}
