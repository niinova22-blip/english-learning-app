import XCTest
@testable import LearningEngine

final class DailyPlanBuilderTests: XCTestCase {
    let startOfToday = Date(timeIntervalSince1970: 1_800_000_000)

    let yds = try! SkillWeights([
        .vocabulary: 35, .grammar: 30, .reading: 35,
        .listening: 0, .writing: 0, .speaking: 0, .pronunciation: 0
    ])

    func lesson(_ id: String, _ skill: Skill, minutes: Int = 8, accessible: Bool = true, completedAt: Date? = nil) -> PlanLesson {
        PlanLesson(id: id, title: "T-\(id)", skill: skill, estimatedMinutes: minutes, isAccessible: accessible, completedAt: completedAt)
    }

    func input(
        dailyMinutes: Int = 20, lessons: [PlanLesson] = [], due: Int = 0, reviewedToday: Int = 0,
        past: [Skill: Double] = [:], weights: SkillWeights? = nil
    ) -> DailyPlanInput {
        DailyPlanInput(
            weights: weights ?? yds, dailyMinutes: dailyMinutes, lessonsInPathOrder: lessons,
            dueNowCount: due, reviewedTodayCount: reviewedToday,
            pastWeekSkillMinutes: past, startOfToday: startOfToday
        )
    }

    func lessonIDs(_ plan: DailyPlan) -> [String] {
        plan.tasks.compactMap { if case .lesson(let id, _, _, _, _) = $0 { return id } else { return nil } }
    }

    func test_reviewTask_isCappedAtHalfTheBudget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 100))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 25, minutes: 10, isDone: false))
    }

    func test_reviewTask_isDoneWhenTodaysReviewsReachTheTarget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 5, reviewedToday: 25))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 25, minutes: 10, isDone: true))
    }

    func test_reviewTask_isDoneWhenNothingIsDueAnymore() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 20, due: 0, reviewedToday: 6))
        XCTAssertEqual(plan.tasks.first, .review(cardCount: 6, minutes: 6 * 0.4, isDone: true))
    }

    func test_noDueAndNoReviewsToday_hasNoReviewTask() {
        let plan = DailyPlanBuilder().build(input(lessons: [lesson("v1", .vocabulary)]))
        XCTAssertEqual(lessonIDs(plan), ["v1"])
        XCTAssertEqual(plan.tasks.count, 1)
    }

    func test_picksTheSkillFurthestBehindItsWeeklyTarget() {
        // past total 100: vocabulary 35-60=-25, grammar 30-0=30, reading 35-40=-5 → grammar first.
        // After g1 (10 min, lesson total 10): grammar has no more lessons; reading -1.5 beats vocabulary -21.5.
        let lessons = [lesson("v1", .vocabulary), lesson("g1", .grammar, minutes: 10), lesson("r1", .reading, minutes: 12)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, past: [.vocabulary: 60, .reading: 40]))
        XCTAssertEqual(lessonIDs(plan), ["g1", "r1"])
        XCTAssertEqual(plan.totalMinutes, 22, accuracy: 1e-9)
    }

    func test_eachSkillOffersLessonsInPathOrder() {
        let lessons = [lesson("v1", .vocabulary, minutes: 5), lesson("v2", .vocabulary, minutes: 5), lesson("v3", .vocabulary, minutes: 5)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 10, lessons: lessons))
        XCTAssertEqual(lessonIDs(plan), ["v1", "v2"])
    }

    func test_zeroWeightSkill_isNeverScheduled() {
        let lessons = [lesson("p1", .pronunciation), lesson("v1", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, past: [.vocabulary: 500]))
        XCTAssertEqual(lessonIDs(plan), ["v1"])
    }

    func test_skillsWithoutLessons_areSkipped() {
        let lessons = [lesson("v1", .vocabulary), lesson("v2", .vocabulary), lesson("v3", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 16, lessons: lessons, past: [.vocabulary: 100]))
        XCTAssertEqual(lessonIDs(plan), ["v1", "v2"])
    }

    func test_atLeastOneLesson_evenWithNoBudget() {
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 0, lessons: [lesson("v1", .vocabulary)], due: 30))
        XCTAssertEqual(plan.tasks, [.lesson(id: "v1", title: "T-v1", skill: .vocabulary, minutes: 8, isDone: false)])
    }

    func test_lessonCompletedToday_staysInPlanAsDone() {
        let lessons = [lesson("v1", .vocabulary, completedAt: startOfToday.addingTimeInterval(3600)), lesson("v2", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 10, lessons: lessons))
        XCTAssertEqual(plan.tasks.first, .lesson(id: "v1", title: "T-v1", skill: .vocabulary, minutes: 8, isDone: true))
    }

    func test_lessonCompletedBeforeToday_isExcluded() {
        let lessons = [lesson("v1", .vocabulary, completedAt: startOfToday.addingTimeInterval(-60)), lesson("v2", .vocabulary)]
        let plan = DailyPlanBuilder().build(input(dailyMinutes: 8, lessons: lessons))
        XCTAssertEqual(lessonIDs(plan), ["v2"])
    }

    func test_previewExhausted_appendsLockedCardForFirstInaccessibleLesson() {
        let lessons = [
            lesson("a1", .vocabulary, completedAt: startOfToday.addingTimeInterval(-86_400)),
            lesson("b1", .vocabulary, accessible: false),
            lesson("b2", .vocabulary, accessible: false),
        ]
        let plan = DailyPlanBuilder().build(input(lessons: lessons, due: 4))
        XCTAssertEqual(plan.tasks, [.review(cardCount: 4, minutes: 4 * 0.4, isDone: false), .locked(id: "b1", title: "T-b1")])
    }

    func test_noLockedCard_whileAnAccessibleLessonIsStillIncomplete() {
        let lessons = [lesson("a1", .vocabulary), lesson("b1", .vocabulary, accessible: false)]
        let plan = DailyPlanBuilder().build(input(lessons: lessons))
        XCTAssertFalse(plan.tasks.contains { if case .locked = $0 { return true } else { return false } })
    }

    func test_emptyInputs_produceAnEmptyCompletePlan() {
        let plan = DailyPlanBuilder().build(input())
        XCTAssertEqual(plan.tasks, [])
        XCTAssertTrue(plan.isComplete)
        XCTAssertEqual(plan.totalMinutes, 0)
    }

    func test_isComplete_ignoresLockedTasks() {
        let lessons = [
            lesson("a1", .vocabulary, completedAt: startOfToday.addingTimeInterval(600)),
            lesson("b1", .vocabulary, accessible: false),
        ]
        let plan = DailyPlanBuilder().build(input(lessons: lessons))
        XCTAssertTrue(plan.isComplete)
    }

    func test_sameInput_sameOutput() {
        let lessons = [lesson("v1", .vocabulary), lesson("g1", .grammar), lesson("r1", .reading)]
        let i = input(lessons: lessons, due: 12, past: [.grammar: 20])
        XCTAssertEqual(DailyPlanBuilder().build(i), DailyPlanBuilder().build(i))
    }

    func test_weeklyBalance_coversActiveSkillsInOrder() {
        let plan = DailyPlanBuilder().build(input(past: [.vocabulary: 30, .reading: 10]))
        XCTAssertEqual(plan.weeklyBalance.map(\.skill), [.vocabulary, .grammar, .reading])
        XCTAssertEqual(plan.weeklyBalance[0].targetShare, 0.35, accuracy: 1e-9)
        XCTAssertEqual(plan.weeklyBalance[0].actualShare, 0.75, accuracy: 1e-9)
        XCTAssertEqual(plan.weeklyBalance[1].actualShare, 0, accuracy: 1e-9)
    }

    func test_weeklyBalance_withNoHistory_hasZeroActualShares() {
        let plan = DailyPlanBuilder().build(input())
        XCTAssertTrue(plan.weeklyBalance.allSatisfy { $0.actualShare == 0 })
    }
}
