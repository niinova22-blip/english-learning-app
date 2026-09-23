import XCTest
@testable import LearningEngine

final class CoachPlannerTests: XCTestCase {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    lazy var today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24))!

    let yds = try! SkillWeights([
        .vocabulary: 35, .grammar: 30, .reading: 35,
        .listening: 0, .writing: 0, .speaking: 0, .pronunciation: 0
    ])

    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }

    /// `open` accessible lessons, `done` accessible lessons completed on the
    /// given day offsets, `locked` inaccessible lessons; 10 minutes each.
    func lessons(open: Int, doneOn: [Int] = [], locked: Int = 0) -> [PlanLesson] {
        var result: [PlanLesson] = []
        for (i, offset) in doneOn.enumerated() {
            result.append(PlanLesson(id: "d\(i)", title: "D\(i)", skill: .vocabulary, estimatedMinutes: 10, isAccessible: true, completedAt: day(offset)))
        }
        for i in 0..<open {
            result.append(PlanLesson(id: "o\(i)", title: "O\(i)", skill: .vocabulary, estimatedMinutes: 10, isAccessible: true, completedAt: nil))
        }
        for i in 0..<locked {
            result.append(PlanLesson(id: "l\(i)", title: "L\(i)", skill: .vocabulary, estimatedMinutes: 10, isAccessible: false, completedAt: nil))
        }
        return result
    }

    func plan(
        exam: Int? = nil, daily: Int = 20, createdDaysAgo: Int = 30,
        lessons: [PlanLesson], past: [Skill: Double] = [:], calendar customCalendar: Calendar? = nil,
        today customToday: Date? = nil, examDate customExam: Date? = nil
    ) -> CoachPlan {
        let cal = customCalendar ?? calendar
        let start = customToday ?? today
        return CoachPlanner(calendar: cal).plan(CoachInput(
            startOfToday: start,
            examDate: customExam ?? exam.map { day($0) },
            dailyMinutes: daily,
            profileCreatedAt: cal.date(byAdding: .day, value: -createdDaysAgo, to: start)!,
            lessonsInPathOrder: lessons, weights: yds, pastWeekSkillMinutes: past
        ))
    }

    func test_capacity_isHalfOfDailyMinutes_roundedDown_atLeastOne() {
        XCTAssertEqual(CoachPlanner.newLessonCapacity(dailyMinutes: 20), 10)
        XCTAssertEqual(CoachPlanner.newLessonCapacity(dailyMinutes: 25), 12)
        XCTAssertEqual(CoachPlanner.newLessonCapacity(dailyMinutes: 0), 1)
    }

    func test_allAccessibleDone_isScopeComplete() {
        let p = plan(exam: 40, lessons: lessons(open: 0, doneOn: [-1, -2], locked: 3))
        XCTAssertEqual(p.status, .scopeComplete)
        XCTAssertEqual(p.directive, CoachDirective(extraLessonMinutes: 0, reviewOnly: true))
        XCTAssertEqual(p.remainingMinutes, 0)
        XCTAssertEqual(p.requiredMinutesPerDay, 0)
        XCTAssertEqual(p.completedShare, 1, accuracy: 1e-9)
        XCTAssertEqual(p.lockedLessonCount, 3)
    }

    func test_examToday_isExamPassed_onFreePace() {
        let p = plan(exam: 0, lessons: lessons(open: 5, doneOn: [-1]))
        XCTAssertEqual(p.status, .examPassed)
        XCTAssertEqual(p.mode, .freePace)
        XCTAssertEqual(p.daysToExam, 0)
        XCTAssertEqual(p.requiredMinutesPerDay, 10)
        XCTAssertEqual(p.daysToTargetFinish, 5)
        XCTAssertFalse(p.directive.reviewOnly)
    }

    func test_examInFiveDays_isFinalWeek_reviewOnly() {
        let p = plan(exam: 5, lessons: lessons(open: 5, doneOn: [-1]))
        XCTAssertEqual(p.status, .finalWeek)
        XCTAssertEqual(p.mode, .examDate)
        XCTAssertEqual(p.daysToExam, 5)
        XCTAssertEqual(p.requiredMinutesPerDay, 0)
        XCTAssertEqual(p.targetFinishDay, today)
        XCTAssertEqual(p.directive, CoachDirective(extraLessonMinutes: 0, reviewOnly: true))
    }

    func test_newLearner_withReachableExam_isNoData_withPace() {
        // 100 minutes over 30 study days (37 - 7) -> ceil(3.33) = 4.
        let p = plan(exam: 37, lessons: lessons(open: 10))
        XCTAssertEqual(p.status, .noData)
        XCTAssertEqual(p.mode, .examDate)
        XCTAssertEqual(p.daysToExam, 37)
        XCTAssertEqual(p.requiredMinutesPerDay, 4)
        XCTAssertEqual(p.targetFinishDay, day(30))
        XCTAssertEqual(p.daysToTargetFinish, 30)
        XCTAssertEqual(p.directive, CoachDirective(extraLessonMinutes: 0, reviewOnly: false))
    }

    func test_impossibleExam_isUnreachable_evenOnDayOne() {
        // 200 minutes over 5 study days = 40/day > 20 daily minutes.
        let p = plan(exam: 12, daily: 20, lessons: lessons(open: 20))
        XCTAssertEqual(p.status, .unreachable(shortfallMinutesPerDay: 20))
        XCTAssertEqual(p.requiredMinutesPerDay, 40)
        XCTAssertEqual(p.directive, CoachDirective(extraLessonMinutes: 10, reviewOnly: false))
    }

    func test_behindSchedule_countsDays_andSpreadsCatchUpOverAWeek() {
        // 200 min over 100 study days -> pace 2. Window 14 days -> expected 28,
        // done 10 -> shortfall 18 -> behind ceil(18/2)=9; catch-up ceil(18/7)=3.
        let p = plan(exam: 107, createdDaysAgo: 30, lessons: lessons(open: 20, doneOn: [-3]))
        XCTAssertEqual(p.requiredMinutesPerDay, 2)
        XCTAssertEqual(p.status, .behind(days: 9))
        XCTAssertEqual(p.directive, CoachDirective(extraLessonMinutes: 3, reviewOnly: false))
    }

    func test_aheadOfSchedule() {
        // 160 min / 100 days -> pace 2. Expected 28, done 50 -> surplus 22 -> 11 days.
        let p = plan(exam: 107, createdDaysAgo: 30, lessons: lessons(open: 16, doneOn: [-1, -2, -3, -4, -5]))
        XCTAssertEqual(p.status, .ahead(days: 11))
        XCTAssertEqual(p.directive.extraLessonMinutes, 0)
    }

    func test_onTrack_whenTheWindowIsClippedToTheProfileCreationDay() {
        // Created 5 days ago -> window 5 days, expected 10, done 10 -> on track.
        let p = plan(exam: 107, createdDaysAgo: 5, lessons: lessons(open: 20, doneOn: [-2]))
        XCTAssertEqual(p.requiredMinutesPerDay, 2)
        XCTAssertEqual(p.status, .onTrack)
    }

    func test_completionToday_countsAsDone_butNotInTheWindow() {
        let p = plan(exam: 107, createdDaysAgo: 5, lessons: lessons(open: 20, doneOn: [0]))
        XCTAssertEqual(p.remainingMinutes, 200)
        XCTAssertEqual(p.status, .behind(days: 5))
    }

    func test_paceAboveCapacity_givesPaceExcessAsExtraMinutes() {
        // 150 min / 10 study days = 15/day; capacity 10 -> extra 5; on track (new).
        let p = plan(exam: 17, createdDaysAgo: 0, lessons: lessons(open: 15, doneOn: [-1]))
        XCTAssertEqual(p.requiredMinutesPerDay, 15)
        XCTAssertEqual(p.status, .onTrack)
        XCTAssertEqual(p.directive.extraLessonMinutes, 5)
    }

    func test_freePace_noExam_newLearner() {
        let p = plan(lessons: lessons(open: 5))
        XCTAssertEqual(p.status, .noData)
        XCTAssertEqual(p.mode, .freePace)
        XCTAssertNil(p.daysToExam)
        XCTAssertEqual(p.requiredMinutesPerDay, 10)
        XCTAssertEqual(p.targetFinishDay, day(5))
        XCTAssertEqual(p.daysToTargetFinish, 5)
    }

    func test_freePace_behind_catchUpIsCappedAtHalfTheDay() {
        // Expected 10*14 = 140, done 10 -> shortfall 130 -> behind 13; catch-up
        // ceil(130/7) = 19, capped at 20 - 10 = 10.
        let p = plan(createdDaysAgo: 30, lessons: lessons(open: 5, doneOn: [-2]))
        XCTAssertEqual(p.status, .behind(days: 13))
        XCTAssertEqual(p.directive.extraLessonMinutes, 10)
    }

    func test_lockedLessons_areCountedSeparately_andExcludedFromScope() {
        let p = plan(lessons: lessons(open: 1, doneOn: [-1], locked: 3))
        XCTAssertEqual(p.lockedLessonCount, 3)
        XCTAssertEqual(p.remainingMinutes, 10)
        XCTAssertEqual(p.completedShare, 0.5, accuracy: 1e-9)
    }

    func test_weakestSkill_isTheLargestPositiveGap() {
        // Total 35: vocabulary .35*35-30 < 0; grammar .30*35-0 = 10.5; reading .35*35-5 = 7.25.
        let p = plan(lessons: lessons(open: 3), past: [.vocabulary: 30, .reading: 5])
        XCTAssertEqual(p.weakestSkill, .grammar)
        XCTAssertNil(plan(lessons: lessons(open: 3)).weakestSkill)
    }

    func test_daysToExam_isCorrectAcrossADaylightSavingChange() {
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let start = ny.date(from: DateComponents(year: 2026, month: 10, day: 30))!
        let exam = ny.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 9))!
        let p = plan(lessons: lessons(open: 3), calendar: ny, today: start, examDate: exam)
        XCTAssertEqual(p.daysToExam, 21)
        XCTAssertEqual(p.targetFinishDay, ny.date(from: DateComponents(year: 2026, month: 11, day: 13)))
    }

    func test_monthEnd_targetFinishRollsIntoNextMonth() {
        let p = plan(exam: 40, lessons: lessons(open: 3))
        XCTAssertEqual(p.targetFinishDay, calendar.date(from: DateComponents(year: 2026, month: 10, day: 27)))
    }
}
