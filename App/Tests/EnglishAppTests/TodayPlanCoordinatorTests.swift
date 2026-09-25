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

    func premiumCoordinator(_ context: ModelContext, level: PackageAccessLevel = .preview) -> TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: level), now: now, calendar: calendar, isPremium: true)
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

    func test_stats_wordsSeen_excludesOrphanedItemsAfterContentUpgrade() throws {
        let context = try makeContext()
        let store = FSRSStateStore()
        // Seen under the v1 item IDs.
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .good, now: now, in: context, scheduler: FSRSScheduler())
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i1", rating: .good, now: now, in: context, scheduler: FSRSScheduler())

        // Upgrade to a v2 with entirely different item IDs; the v1 UserItemState
        // rows above are kept (per spec) but now refer to nonexistent items.
        let outcome = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 2, prefix: "newitem"), into: context)
        XCTAssertEqual(outcome, .upgraded(from: 1, to: 2))

        // Seen under a v2 item ID after the upgrade.
        try store.recordReview(userID: userID, itemID: "newitem-u0-l0-i0", rating: .good, now: now, in: context, scheduler: FSRSScheduler())

        let stats = try coordinator(context).stats()
        XCTAssertEqual(stats.wordsSeen, 1)
    }

    func test_planInput_dueNowCount_excludesOrphanedItemsAfterContentUpgrade() throws {
        let context = try makeContext()
        let store = FSRSStateStore()
        // Due now under a v1 item ID.
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        try store.recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .again, now: yesterday, in: context, scheduler: FSRSScheduler())

        // Upgrade to a v2 with entirely different item IDs; the v1 UserItemState
        // row above is kept (per spec) but now refers to a nonexistent item.
        let outcome = try ContentSeeder.seed(bundledData: TestPackageJSON.make(version: 2, prefix: "newitem"), into: context)
        XCTAssertEqual(outcome, .upgraded(from: 1, to: 2))

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.dueNowCount, 0)
    }

    func makeRealContentContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    /// A due practice card must produce a practiceReview task and must NOT be
    /// counted as a due vocabulary word.
    func test_duePracticeCard_becomesAPracticeReviewTask_andIsNotCountedAsAVocabularyReview() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(
            userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5,
            dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past
        ))
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.dueNowCount, 0, "a due grammar topic must not inflate the vocabulary review task")
        XCTAssertEqual(input.duePracticeCards.map(\.itemID), ["yds-practice-card-tenses"])
        XCTAssertEqual(input.duePracticeCards.first?.skill, .grammar)
        XCTAssertEqual(input.duePracticeCards.first?.lessonID, "yds-practice-lesson-tenses")
        XCTAssertEqual(input.duePracticeCards.first?.title, "Tenses")
        XCTAssertFalse(input.duePracticeCards.first?.isDone ?? true)

        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        XCTAssertTrue(plan.tasks.contains { if case .practiceReview(let id, _, _, _, _, _) = $0 { return id == "yds-practice-card-tenses" } else { return false } })
    }

    func test_bugun_schedulesAPracticeLessonOnceGrammarIsBehindItsWeeklyTarget() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()

        let plan = try XCTUnwrap(coordinator(context).buildPlan())
        let actions = plan.tasks.map(PlanTaskAction.action(for:))
        XCTAssertTrue(
            actions.contains { if case .startPractice = $0 { return true } else { return false } },
            "with grammar and reading weighted at 30/35, the first plan must include a practice lesson"
        )
        XCTAssertFalse(
            actions.contains { if case .comingSoon = $0 { return true } else { return false } },
            "no shipped lesson may still route to 'coming soon'"
        )
    }

    func test_practiceCards_areNotCountedAsWordsSeen() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        context.insert(UserItemState(userID: userID, itemID: "yds-vocab1-item-economy", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        try context.save()

        XCTAssertEqual(try coordinator(context).stats().wordsSeen, 1)
    }

    func test_aPracticeCardReviewedToday_marksTheTaskDone() throws {
        let context = try makeRealContentContext()
        _ = try coordinator(context).ensureProfile()
        let past = now.addingTimeInterval(-3600)
        context.insert(UserItemState(userID: userID, itemID: "yds-practice-card-tenses", stability: 1, difficulty: 5, dueDate: past, reps: 1, lapses: 0, lastReviewedAt: past))
        context.insert(ReviewLog(userID: userID, itemID: "yds-practice-card-tenses", rating: .good, reviewedAt: past, reactionTimeMs: 0))
        try context.save()

        let input = try XCTUnwrap(coordinator(context).buildPlanInput())
        XCTAssertEqual(input.reviewedTodayCount, 0, "a practice review must not count as a vocabulary review")
        XCTAssertTrue(input.duePracticeCards.first?.isDone ?? false)
    }

    func test_planInput_nonPremium_hasNoCoachDirective() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(coordinator(context).ensureProfile())
        profile.examDate = calendar.date(byAdding: .day, value: 5, to: now)
        try context.save()
        XCTAssertNil(try XCTUnwrap(coordinator(context).buildPlanInput()).coach)
    }

    func test_planInput_premium_finalWeek_isReviewOnly_andPlanHasNoLessons() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(premiumCoordinator(context).ensureProfile())
        profile.examDate = calendar.date(byAdding: .day, value: 5, to: now)
        try context.save()
        let input = try XCTUnwrap(premiumCoordinator(context).buildPlanInput())
        XCTAssertEqual(input.coach, CoachDirective(extraLessonMinutes: 0, reviewOnly: true))
        let plan = try XCTUnwrap(premiumCoordinator(context).buildPlan())
        XCTAssertFalse(plan.tasks.contains { if case .lesson = $0 { return true } else { return false } })
    }

    func test_coachBriefing_freePace_countsLockedLessons_andLastWeek() throws {
        let context = try makeContext()
        let profile = try XCTUnwrap(premiumCoordinator(context).ensureProfile())
        profile.createdAt = calendar.date(byAdding: .day, value: -10, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let progress = LessonProgress(userID: userID, lessonID: "lesson-u0-l0", startedAt: twoDaysAgo)
        progress.completedAt = twoDaysAgo
        context.insert(progress)
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i0", rating: .good, reviewedAt: twoDaysAgo))
        context.insert(ReviewLog(userID: userID, itemID: "item-u0-l1-i1", rating: .good, reviewedAt: calendar.date(byAdding: .day, value: -3, to: now)!))
        try context.save()

        let briefing = try XCTUnwrap(premiumCoordinator(context, level: .preview).buildCoachBriefing())
        XCTAssertEqual(briefing.plan.mode, .freePace)
        XCTAssertNil(briefing.plan.daysToExam)
        XCTAssertEqual(briefing.plan.lockedLessonCount, 2)
        XCTAssertEqual(briefing.plan.remainingMinutes, 8)
        XCTAssertEqual(briefing.plan.completedShare, 0.5, accuracy: 1e-9)
        XCTAssertEqual(briefing.weekLessonsCompleted, 1)
        XCTAssertEqual(briefing.weekDaysStudied, 2)
        XCTAssertEqual(briefing.weekMinutes, 9) // 8 lesson minutes + 2 reviews * 0.4, rounded
    }

    func test_coachBriefing_isNil_withoutContent() throws {
        XCTAssertNil(try premiumCoordinator(try makeContext(seed: false)).buildCoachBriefing())
    }

    func test_coachBriefing_ignoresOrphanedProgressRows() throws {
        let context = try makeContext()
        _ = try XCTUnwrap(premiumCoordinator(context).ensureProfile())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        context.insert(ReviewLog(userID: userID, itemID: "gone-item", rating: .good, reviewedAt: twoDaysAgo))
        let progress = LessonProgress(userID: userID, lessonID: "gone-lesson", startedAt: twoDaysAgo)
        progress.completedAt = twoDaysAgo
        context.insert(progress)
        try context.save()

        let briefing = try XCTUnwrap(premiumCoordinator(context).buildCoachBriefing())
        XCTAssertEqual(briefing.weekDaysStudied, 0)
        XCTAssertEqual(briefing.weekLessonsCompleted, 0)
        XCTAssertEqual(briefing.weekMinutes, 0)
    }
}
