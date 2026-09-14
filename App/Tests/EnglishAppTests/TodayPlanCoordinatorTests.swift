import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

struct FixedAccessProvider: PackageAccessProvider {
    let level: PackageAccessLevel
    func accessLevel(forPackageID id: String) -> PackageAccessLevel { level }
}

final class TodayPlanCoordinatorTests: XCTestCase {
    let userID = "u"
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    lazy var now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 15))!
    lazy var startOfToday = calendar.startOfDay(for: now)

    func makeContext(seed: Bool = true) throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        if seed { _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context) }
        return context
    }

    func coordinator(_ context: ModelContext, level: PackageAccessLevel = .preview) -> TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: level), now: now, calendar: calendar)
    }

    func test_ensureProfile_createsDefaultForFirstPackage_once() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(coordinator(context).ensureProfile())
        XCTAssertEqual(profile.activePackageID, "pkg")
        XCTAssertEqual(profile.dailyMinutes, 20)
        _ = try coordinator(context).ensureProfile()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LearnerProfile>()), 1)
    }

    func test_ensureProfile_repairsMissingActivePackage() throws {
        let context = try makeContext()
        context.insert(LearnerProfile(userID: userID, activePackageID: "gone", createdAt: now))
        try context.save()
        XCTAssertEqual(try coordinator(context).ensureProfile()?.activePackageID, "pkg")
    }

    func test_noPackages_meansNoProfileAndNoPlan() throws {
        let context = try makeContext(seed: false)
        XCTAssertNil(try coordinator(context).ensureProfile())
        XCTAssertNil(try coordinator(context).buildPlan())
    }

    func test_planInput_lessonsInPathOrder_withPreviewAccess() throws {
        let context = try makeContext()
        let input = try XCTUnwrap(coordinator(context, level: .preview).buildPlanInput())
        XCTAssertEqual(input.lessonsInPathOrder.map(\.id), ["lesson-u0-l0", "lesson-u0-l1", "lesson-u1-l0", "lesson-u1-l1"])
        XCTAssertEqual(input.lessonsInPathOrder.map(\.isAccessible), [true, true, false, false])
        XCTAssertEqual(input.lessonsInPathOrder[0].title, "Unit 0 · 1")
        XCTAssertEqual(input.dailyMinutes, 20)
        XCTAssertEqual(input.startOfToday, startOfToday)
    }

    func test_planInput_ownedAccess_unlocksEverything() throws {
        let context = try makeContext()
        let input = try XCTUnwrap(coordinator(context, level: .owned).buildPlanInput())
        XCTAssertTrue(input.lessonsInPathOrder.allSatisfy(\.isAccessible))
    }

    func test_planInput_dueAndReviewedTodayCounts() throws {
        let context = try makeContext()
        let store = FSRSStateStore()
        // Reviewed yesterday → due today (min interval is 1 day).
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .again, now: yesterday, in: context, scheduler: FSRSScheduler())
        // Reviewed twice today → counts once, not due now.
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now.addingTimeInterval(-600), in: context, scheduler: FSRSScheduler())
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now.addingTimeInterval(-300), in: context, scheduler: FSRSScheduler())

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.dueNowCount, 1)
        XCTAssertEqual(input.reviewedTodayCount, 1)
    }

    func test_planInput_pastWeekMinutes_useLessonsAndReviewsBeforeToday() throws {
        let context = try makeContext()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: twoDaysAgo)
        progress.completedAt = twoDaysAgo
        context.insert(progress)
        for i in 0..<5 {
            context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i\(i % 2)", rating: .good, reviewedAt: calendar.date(byAdding: .day, value: -3, to: now)!))
        }
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i0", rating: .good, reviewedAt: now))                                   // today: excluded
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i0", rating: .good, reviewedAt: calendar.date(byAdding: .day, value: -8, to: now)!)) // too old
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.pastWeekSkillMinutes[.vocabulary] ?? 0, 8 + 5 * 0.4, accuracy: 1e-9)
        XCTAssertEqual(input.lessonsInPathOrder[0].completedAt, twoDaysAgo)
    }

    func test_buildPlan_firstDay_schedulesPreviewLessons() throws {
        let context = try makeContext()
        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        XCTAssertEqual(plan.tasks.first, .lesson(id: "lesson-u0-l0", title: "Unit 0 · 1", skill: .vocabulary, minutes: 8, isDone: false))
    }

    func test_streak_andStats() throws {
        let context = try makeContext()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l0-i0", rating: .good, reviewedAt: yesterday))
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now, in: context, scheduler: FSRSScheduler())
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: now)
        progress.completedAt = now
        context.insert(progress)
        try context.save()

        let c = coordinator(context)
        XCTAssertEqual(try c.streak(), 2)
        let stats = try c.stats()
        XCTAssertEqual(stats.wordsSeen, 1)
        XCTAssertEqual(stats.completedLessons, 1)
        XCTAssertEqual(stats.totalLessons, 4)
        XCTAssertEqual(stats.packageName, "Test pkg")
        XCTAssertEqual(stats.accessLevel, .preview)
        XCTAssertEqual(stats.dailyMinutes, 20)
    }
}
