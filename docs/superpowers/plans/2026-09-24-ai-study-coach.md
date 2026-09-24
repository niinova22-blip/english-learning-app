# AI Study Coach (Slice 9) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A premium study coach that turns the learner's exam date into a rule-based programme which really drives the daily plan, narrated by a Turkish template (always) or an on-device model note (on request).

**Architecture:** A pure `CoachPlanner` in LearningEngine computes status, pace and a `CoachDirective`; `DailyPlanBuilder` takes the directive as an optional input (nil = today's behaviour, byte-for-byte). TutorEngine gains a coach prompt, a note validator and a protocol method. The App builds the briefing in `TodayPlanCoordinator`, renders Turkish templates, and shows a coach card on Today, a coach section on Profile and a study settings sheet.

**Tech Stack:** Swift 5.10, SwiftUI (iOS 17), SwiftData, XCTest, MLX Swift (mlx-swift-examples 2.29.1), XcodeGen, GitHub Actions CI.

**Spec:** `docs/superpowers/specs/2026-09-24-ai-study-coach-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification is: commit, push, confirm both CI workflows green — `Swift Tests` (`scripts/ci-test.sh`, runs LearningEngine + TutorEngine) and `App Build` (`scripts/ci-app-build.sh`, builds the app and runs `App/Tests/EnglishAppTests` on the iOS Simulator). Check with `"C:/Program Files/GitHub CLI/gh.exe" run list --branch learning-engine --limit 4`; App Build takes ~12-15 minutes.
- **Pushed commits are never amended or force-pushed.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with a blank line and then** `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Use single-quoted heredocs (`git commit -F - <<'EOF'`); no backticks or `$(...)` inside double-quoted bash strings. Write Turkish text with the Write/Edit tools, not bash heredocs.
- **Real Python only** if Python is ever needed: `"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe"`. Never bare `python`/`python3`.
- **No SwiftData schema change.** No new `@Model` types, no new stored properties on existing models.
- **Free learners' daily plan is byte-for-byte unchanged** (`coach: nil`).
- **The model never computes numbers;** every model note passes `CoachNoteValidator` or the template is shown.
- **Opening Today never loads the model.** Only the "Koçtan kişisel not al" button does.
- **All learner-facing text is Turkish** with real diacritics (`ı İ ş ğ ü ö ç`), informal "sen" register. New UI strings are string literals in SwiftUI views (the String Catalog `Localizable.xcstrings` picks them up at build time; do not hand-edit it).
- **Tests assert concrete values.** Constants: `CoachPlanner.finalWeekDays = 7`, `trackingWindowDays = 14`, `catchUpSpreadDays = 7`; `CoachNoteValidator.maxCharacters = 400`; coach timeout 30 s; daily minutes range `10...60` step 5.
- **Adding a requirement to the `TutorEngine` protocol breaks every conforming fake** (`App/Tests/EnglishAppTests/TutorViewModelTests.swift` `FakeTutorEngine`, `ChatViewModelTests.swift` `FakeChatEngine` and `ControllableChatEngine`). The task that adds the requirement also adds the stubs, in the same commit.

## Review Focus

1. **Exam date that is today, in the past, or within 7 days** → `examPassed` / `finalWeek`, never a division by zero or a negative pace. Pinned in Task 1 (`test_examToday_isExamPassed_onFreePace`, `test_examInFiveDays_isFinalWeek_reviewOnly`).
2. **Everything accessible already completed (or a preview user who finished the free unit)** → `scopeComplete`, review-only plan, no "0 dk" pace nonsense. Pinned in Task 1 (`test_allAccessibleDone_isScopeComplete`) and Task 2 (`test_reviewOnly_addsNoLessons_evenWithNothingDue`).
3. **A model reply containing a made-up number, empty text or a very long reply** → template stays. Pinned in Task 3 (validator tests) and Task 4 (`test_requestPersonalNote_foreignNumber_keepsTemplate`).
4. **Status changes during the day while a model note is cached or being generated** (the learner finishes a lesson, the template changes) → the stale note is not shown. Pinned in Task 4 (`test_cachedNote_isIgnored_whenTheTemplateChanged`).
5. **Premium lapses** → plan returns to free behaviour at once. Pinned in Task 5 (`test_planInput_nonPremium_hasNoCoachDirective`).

---

### Task 1: CoachPlanner and coach types (LearningEngine)

**Files:**
- Create: `LearningEngine/Sources/LearningEngine/Planning/CoachTypes.swift`
- Create: `LearningEngine/Sources/LearningEngine/Planning/CoachPlanner.swift`
- Test: `LearningEngine/Tests/LearningEngineTests/CoachPlannerTests.swift`

**Interfaces:**
- Consumes: `PlanLesson`, `SkillWeights`, `Skill` (existing), `DailyPlanBuilder.maxReviewShareOfBudget` (existing, `0.5`).
- Produces (all `public`): `CoachMode`, `CoachStatus`, `CoachDirective(extraLessonMinutes: Int, reviewOnly: Bool)`, `CoachInput`, `CoachPlan`, `CoachBriefing`, `CoachPlanner(calendar:)` with `func plan(_ input: CoachInput) -> CoachPlan` and `static func newLessonCapacity(dailyMinutes: Int) -> Int`.

- [ ] **Step 1: Write the types file**

`LearningEngine/Sources/LearningEngine/Planning/CoachTypes.swift`:

```swift
import Foundation

public enum CoachMode: Sendable, Equatable {
    /// A future exam date sets the deadline.
    case examDate
    /// No usable exam date: the pace is the day's normal new-lesson capacity.
    case freePace
}

public enum CoachStatus: Sendable, Equatable {
    case scopeComplete
    case examPassed
    case finalWeek
    case unreachable(shortfallMinutesPerDay: Int)
    case noData
    case behind(days: Int)
    case ahead(days: Int)
    case onTrack
}

/// What the coach asks of today's plan. `DailyPlanBuilder` treats a nil
/// directive exactly like before the coach existed.
public struct CoachDirective: Sendable, Equatable {
    public let extraLessonMinutes: Int
    public let reviewOnly: Bool

    public init(extraLessonMinutes: Int, reviewOnly: Bool) {
        self.extraLessonMinutes = extraLessonMinutes
        self.reviewOnly = reviewOnly
    }
}

public struct CoachInput: Sendable, Equatable {
    public let startOfToday: Date
    public let examDate: Date?
    public let dailyMinutes: Int
    public let profileCreatedAt: Date
    public let lessonsInPathOrder: [PlanLesson]
    public let weights: SkillWeights
    public let pastWeekSkillMinutes: [Skill: Double]

    public init(
        startOfToday: Date, examDate: Date?, dailyMinutes: Int, profileCreatedAt: Date,
        lessonsInPathOrder: [PlanLesson], weights: SkillWeights, pastWeekSkillMinutes: [Skill: Double]
    ) {
        self.startOfToday = startOfToday
        self.examDate = examDate
        self.dailyMinutes = dailyMinutes
        self.profileCreatedAt = profileCreatedAt
        self.lessonsInPathOrder = lessonsInPathOrder
        self.weights = weights
        self.pastWeekSkillMinutes = pastWeekSkillMinutes
    }
}

public struct CoachPlan: Sendable, Equatable {
    public let status: CoachStatus
    public let mode: CoachMode
    /// Whole days from today to the exam day; nil without an exam date.
    public let daysToExam: Int?
    /// Day by which the accessible new lessons should be finished; nil when
    /// nothing remains on free pace.
    public let targetFinishDay: Date?
    public let daysToTargetFinish: Int?
    public let remainingMinutes: Int
    public let completedShare: Double
    public let lockedLessonCount: Int
    public let requiredMinutesPerDay: Int
    public let weakestSkill: Skill?
    public let directive: CoachDirective

    public init(
        status: CoachStatus, mode: CoachMode, daysToExam: Int?, targetFinishDay: Date?,
        daysToTargetFinish: Int?, remainingMinutes: Int, completedShare: Double,
        lockedLessonCount: Int, requiredMinutesPerDay: Int, weakestSkill: Skill?,
        directive: CoachDirective
    ) {
        self.status = status
        self.mode = mode
        self.daysToExam = daysToExam
        self.targetFinishDay = targetFinishDay
        self.daysToTargetFinish = daysToTargetFinish
        self.remainingMinutes = remainingMinutes
        self.completedShare = completedShare
        self.lockedLessonCount = lockedLessonCount
        self.requiredMinutesPerDay = requiredMinutesPerDay
        self.weakestSkill = weakestSkill
        self.directive = directive
    }
}

/// Everything the coach note is written from: the plan plus the last 7 days
/// (the 7 whole days before today).
public struct CoachBriefing: Sendable, Equatable {
    public let plan: CoachPlan
    public let weekDaysStudied: Int
    public let weekMinutes: Int
    public let weekLessonsCompleted: Int
    public let streak: Int

    public init(plan: CoachPlan, weekDaysStudied: Int, weekMinutes: Int, weekLessonsCompleted: Int, streak: Int) {
        self.plan = plan
        self.weekDaysStudied = weekDaysStudied
        self.weekMinutes = weekMinutes
        self.weekLessonsCompleted = weekLessonsCompleted
        self.streak = streak
    }
}
```

- [ ] **Step 2: Write the failing planner tests**

`LearningEngine/Tests/LearningEngineTests/CoachPlannerTests.swift`:

```swift
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
```

- [ ] **Step 3: Write the planner**

`LearningEngine/Sources/LearningEngine/Planning/CoachPlanner.swift`:

```swift
import Foundation

/// Turns the exam date, the path and recent study into a programme. Pure: no
/// clock reads and no SwiftData, so identical inputs give identical plans.
public struct CoachPlanner: Sendable {
    public static let finalWeekDays = 7
    public static let trackingWindowDays = 14
    public static let catchUpSpreadDays = 7

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// New-lesson minutes of a normal day: what `DailyPlanBuilder` leaves after
    /// its maximum review share.
    public static func newLessonCapacity(dailyMinutes: Int) -> Int {
        let share = 1 - DailyPlanBuilder.maxReviewShareOfBudget
        return max(1, Int((Double(max(dailyMinutes, 0)) * share).rounded(.down)))
    }

    public func plan(_ input: CoachInput) -> CoachPlan {
        let today = calendar.startOfDay(for: input.startOfToday)
        let daily = max(input.dailyMinutes, 0)
        let capacity = Self.newLessonCapacity(dailyMinutes: daily)

        let accessible = input.lessonsInPathOrder.filter(\.isAccessible)
        let remaining = accessible.filter { $0.completedAt == nil }.reduce(0) { $0 + $1.estimatedMinutes }
        let accessibleTotal = accessible.reduce(0) { $0 + $1.estimatedMinutes }
        let completedShare = accessibleTotal > 0 ? Double(accessibleTotal - remaining) / Double(accessibleTotal) : 0
        let lockedCount = input.lessonsInPathOrder.filter { !$0.isAccessible }.count
        let daysToExam = input.examDate.map { days(from: today, to: calendar.startOfDay(for: $0)) }

        // Mode, pace and target finish day.
        let mode: CoachMode = (daysToExam ?? 0) > 0 ? .examDate : .freePace
        var pace = 0
        var daysToFinish: Int?
        if mode == .examDate, let d = daysToExam {
            let studyDays = d - Self.finalWeekDays
            if studyDays > 0 {
                pace = remaining == 0 ? 0 : ceilDiv(remaining, studyDays)
                daysToFinish = studyDays
            } else {
                daysToFinish = 0
            }
        } else if remaining > 0 {
            pace = capacity
            daysToFinish = ceilDiv(remaining, capacity)
        }
        let targetFinish = daysToFinish.flatMap { calendar.date(byAdding: .day, value: $0, to: today) }

        // Tracking window: last 14 days before today, never before the profile existed.
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -Self.trackingWindowDays, to: today)!
        let windowStart = max(calendar.startOfDay(for: input.profileCreatedAt), fourteenDaysAgo)
        let windowDays = max(0, days(from: windowStart, to: today))
        let doneInWindow = input.lessonsInPathOrder.reduce(0) { sum, lesson in
            guard let completedAt = lesson.completedAt, completedAt >= windowStart, completedAt < today else { return sum }
            return sum + lesson.estimatedMinutes
        }
        let balance = doneInWindow - pace * windowDays
        let hasAnyCompletion = input.lessonsInPathOrder.contains { $0.completedAt != nil }

        let status: CoachStatus
        if remaining == 0 {
            status = .scopeComplete
        } else if let d = daysToExam, d <= 0 {
            status = .examPassed
        } else if let d = daysToExam, d <= Self.finalWeekDays {
            status = .finalWeek
        } else if mode == .examDate && pace > daily {
            status = .unreachable(shortfallMinutesPerDay: pace - daily)
        } else if !hasAnyCompletion {
            status = .noData
        } else if pace > 0 && windowDays > 0 && balance <= -pace {
            status = .behind(days: ceilDiv(-balance, pace))
        } else if pace > 0 && windowDays > 0 && balance >= pace {
            status = .ahead(days: balance / pace)
        } else {
            status = .onTrack
        }

        let reviewOnly = status == .scopeComplete || status == .finalWeek
        var extra = 0
        if !reviewOnly {
            let paceExcess = mode == .examDate ? max(0, pace - capacity) : 0
            var catchUp = 0
            if case .behind = status { catchUp = ceilDiv(-balance, Self.catchUpSpreadDays) }
            extra = min(max(0, daily - capacity), paceExcess + catchUp)
        }

        return CoachPlan(
            status: status, mode: mode, daysToExam: daysToExam,
            targetFinishDay: targetFinish, daysToTargetFinish: daysToFinish,
            remainingMinutes: remaining, completedShare: completedShare,
            lockedLessonCount: lockedCount, requiredMinutesPerDay: pace,
            weakestSkill: weakestSkill(input),
            directive: CoachDirective(extraLessonMinutes: extra, reviewOnly: reviewOnly)
        )
    }

    private func days(from start: Date, to end: Date) -> Int {
        calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    private func ceilDiv(_ a: Int, _ b: Int) -> Int {
        precondition(b > 0)
        return (a + b - 1) / b
    }

    /// The active skill furthest behind its share of last week's minutes;
    /// earlier `Skill.allCases` position wins ties. Nil without last-week study
    /// or when no skill is behind.
    private func weakestSkill(_ input: CoachInput) -> Skill? {
        let total = input.pastWeekSkillMinutes.values.reduce(0, +)
        guard total > 0 else { return nil }
        var best: (skill: Skill, gap: Double)?
        for skill in input.weights.activeSkills {
            let gap = input.weights.share(of: skill) * total - (input.pastWeekSkillMinutes[skill] ?? 0)
            if best == nil || gap > best!.gap { best = (skill, gap) }
        }
        guard let best, best.gap > 0 else { return nil }
        return best.skill
    }
}
```

Note the `ceilDiv` precondition: `studyDays > 0` and `capacity >= 1` guarantee `b > 0` at every call; `-balance` is positive whenever `.behind` was chosen.

- [ ] **Step 4: Commit, push, verify CI**

```bash
git add LearningEngine/Sources/LearningEngine/Planning/CoachTypes.swift LearningEngine/Sources/LearningEngine/Planning/CoachPlanner.swift LearningEngine/Tests/LearningEngineTests/CoachPlannerTests.swift
git commit -F - <<'EOF'
Add the coach planner that turns the exam date into a study programme

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: `Swift Tests` green including the 17 `CoachPlannerTests`; `App Build` green (unchanged app). If a test fails on CI, fix the code (not the expected value) unless the expected value contradicts the spec — then report it.

---

### Task 2: DailyPlanBuilder takes the coach directive

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift` (`DailyPlanInput`, `DailyPlan`, `build(_:)`)
- Test: `LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift` (append)

**Interfaces:**
- Consumes: `CoachDirective` (Task 1).
- Produces: `DailyPlanInput.coach: CoachDirective?` (init parameter `coach: CoachDirective? = nil`, last); `DailyPlan.coachAddedLessonIDs: [String]` (init parameter `coachAddedLessonIDs: [String] = []`, last).

- [ ] **Step 1: Write the failing tests** (append inside `DailyPlanBuilderTests`; the existing `input(...)` helper gains a `coach:` parameter as shown)

Change the existing helper to:

```swift
    func input(
        dailyMinutes: Int = 20, lessons: [PlanLesson] = [], due: Int = 0, reviewedToday: Int = 0,
        past: [Skill: Double] = [:], weights: SkillWeights? = nil,
        practice: [DuePracticeCard] = [], coach: CoachDirective? = nil
    ) -> DailyPlanInput {
        DailyPlanInput(
            weights: weights ?? yds, dailyMinutes: dailyMinutes, lessonsInPathOrder: lessons,
            dueNowCount: due, reviewedTodayCount: reviewedToday,
            pastWeekSkillMinutes: past, startOfToday: startOfToday,
            duePracticeCards: practice, coach: coach
        )
    }
```

Append:

```swift
    func lessonIDs(_ plan: DailyPlan) -> [String] {
        plan.tasks.compactMap { if case .lesson(let id, _, _, _, _) = $0 { return id } else { return nil } }
    }

    func vocabLessons(_ count: Int) -> [PlanLesson] {
        (1...count).map { lesson("v\($0)", .vocabulary) }
    }

    func test_coach_nilAndNeutralDirective_giveTheSamePlanAsBefore() {
        let base = input(dailyMinutes: 20, lessons: vocabLessons(6), due: 10, practice: [card("p1", .grammar)])
        let plain = DailyPlanBuilder().build(base)
        let neutral = DailyPlanBuilder().build(input(
            dailyMinutes: 20, lessons: vocabLessons(6), due: 10, practice: [card("p1", .grammar)],
            coach: CoachDirective(extraLessonMinutes: 0, reviewOnly: false)
        ))
        XCTAssertEqual(plain, neutral)
        XCTAssertEqual(plain.coachAddedLessonIDs, [])
    }

    func test_coach_extraMinutes_addLessonsBeyondTheBudget_andTagThem() {
        // Normal fill: 8, 16, 24 -> three lessons. Extra 10 -> keep adding while < 30 -> a fourth.
        let normal = DailyPlanBuilder().build(input(dailyMinutes: 20, lessons: vocabLessons(6)))
        XCTAssertEqual(lessonIDs(normal), ["v1", "v2", "v3"])

        let coached = DailyPlanBuilder().build(input(
            dailyMinutes: 20, lessons: vocabLessons(6),
            coach: CoachDirective(extraLessonMinutes: 10, reviewOnly: false)
        ))
        XCTAssertEqual(lessonIDs(coached), ["v1", "v2", "v3", "v4"])
        XCTAssertEqual(coached.coachAddedLessonIDs, ["v4"])
        XCTAssertEqual(coached.totalMinutes, 32, accuracy: 1e-9)
    }

    func test_reviewOnly_letsReviewsUseTheWholeDay_andAddsNoLessons() {
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 20, lessons: vocabLessons(3), due: 60,
            coach: CoachDirective(extraLessonMinutes: 0, reviewOnly: true)
        ))
        guard case .review(let count, let minutes, _) = plan.tasks.first else { return XCTFail("expected a review task") }
        XCTAssertEqual(count, 50)
        XCTAssertEqual(minutes, 20, accuracy: 1e-9)
        XCTAssertEqual(lessonIDs(plan), [])
        XCTAssertEqual(plan.coachAddedLessonIDs, [])
    }

    func test_reviewOnly_addsNoLessons_evenWithNothingDue() {
        let plan = DailyPlanBuilder().build(input(
            dailyMinutes: 20, lessons: vocabLessons(3),
            coach: CoachDirective(extraLessonMinutes: 5, reviewOnly: true)
        ))
        XCTAssertEqual(lessonIDs(plan), [])
        XCTAssertEqual(plan.totalMinutes, 0, accuracy: 1e-9)
    }
```

- [ ] **Step 2: Implement**

In `DailyPlanInput` add the stored property and init parameter:

```swift
    public let duePracticeCards: [DuePracticeCard]
    /// Premium coach instructions; nil keeps the plan exactly as without a coach.
    public let coach: CoachDirective?

    public init(
        weights: SkillWeights, dailyMinutes: Int, lessonsInPathOrder: [PlanLesson],
        dueNowCount: Int, reviewedTodayCount: Int,
        pastWeekSkillMinutes: [Skill: Double], startOfToday: Date,
        duePracticeCards: [DuePracticeCard] = [],
        coach: CoachDirective? = nil
    ) {
        // ... existing assignments unchanged ...
        self.duePracticeCards = duePracticeCards
        self.coach = coach
    }
```

In `DailyPlan`:

```swift
    public let weeklyBalance: [SkillBalance]
    /// Lessons that are in the plan only because the coach asked for extra time.
    public let coachAddedLessonIDs: [String]

    public init(tasks: [PlanTask], totalMinutes: Double, weeklyBalance: [SkillBalance], coachAddedLessonIDs: [String] = []) {
        self.tasks = tasks
        self.totalMinutes = totalMinutes
        self.weeklyBalance = weeklyBalance
        self.coachAddedLessonIDs = coachAddedLessonIDs
    }
```

In `build(_:)`:

1. Replace the review cap line with:

```swift
        let reviewOnly = input.coach?.reviewOnly ?? false
        // 1. Review task. In the coach's review-only days reviews may fill the day.
        let reviewShare = reviewOnly ? 1.0 : Self.maxReviewShareOfBudget
        let reviewCap = Int((budget * reviewShare / Self.minutesPerReviewCard).rounded(.down))
```

(and remove the now-duplicated `// 1. Review task.` comment above it).

2. Replace the lesson-fill block

```swift
        while reviewMinutes + practiceMinutes + plannedLessonMinutes < budget, let lesson = nextLesson() {
            add(lesson)
        }
        // 3. At least one lesson when any candidate exists.
        if !addedAny, let lesson = nextLesson() {
            add(lesson)
        }
```

with

```swift
        var coachAdded: [String] = []
        if !reviewOnly {
            while reviewMinutes + practiceMinutes + plannedLessonMinutes < budget, let lesson = nextLesson() {
                add(lesson)
            }
            // 3. At least one lesson when any candidate exists.
            if !addedAny, let lesson = nextLesson() {
                add(lesson)
            }
            // 4. Coach catch-up: keep adding past the budget by the coach's extra minutes.
            let extra = Double(max(input.coach?.extraLessonMinutes ?? 0, 0))
            while extra > 0, reviewMinutes + practiceMinutes + plannedLessonMinutes < budget + extra, let lesson = nextLesson() {
                add(lesson)
                coachAdded.append(lesson.id)
            }
        }
```

3. Pass it into the result:

```swift
        return DailyPlan(
            tasks: tasks, totalMinutes: reviewMinutes + practiceMinutes + plannedLessonMinutes,
            weeklyBalance: balance, coachAddedLessonIDs: coachAdded
        )
```

The locked-card step (5) and the balance computation are unchanged.

- [ ] **Step 3: Commit, push, verify CI**

```bash
git add LearningEngine/Sources/LearningEngine/Planning/DailyPlanBuilder.swift LearningEngine/Tests/LearningEngineTests/DailyPlanBuilderTests.swift
git commit -F - <<'EOF'
Let the daily plan follow the coach directive for catch-up and review-only days

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: both workflows green; every pre-existing `DailyPlanBuilderTests` test still passes unchanged (they use `coach: nil`).

---

### Task 3: Coach request, prompt and validator in TutorEngine

**Files:**
- Create: `TutorEngine/Sources/TutorEngine/CoachRequest.swift`
- Modify: `TutorEngine/Sources/TutorEngine/TutorRequest.swift` (protocol)
- Modify: `TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift`
- Modify: `App/Tests/EnglishAppTests/TutorViewModelTests.swift`, `App/Tests/EnglishAppTests/ChatViewModelTests.swift` (stubs)
- Test: `TutorEngine/Tests/TutorEngineTests/CoachPromptBuilderTests.swift`, `TutorEngine/Tests/TutorEngineTests/CoachNoteValidatorTests.swift`

**Interfaces:**
- Consumes: `ChatPromptMessage` (existing).
- Produces: `CoachRequest(facts: [String], draft: String)`; `CoachPromptBuilder.systemInstructions: String`, `CoachPromptBuilder.build(for: CoachRequest) -> [ChatPromptMessage]`; `CoachNoteValidator.maxCharacters = 400`, `CoachNoteValidator.validate(_ text: String, for: CoachRequest) -> String?` (returns the trimmed text or nil); protocol requirement `func respond(to coach: CoachRequest) async throws -> String`.

- [ ] **Step 1: Write the failing tests**

`TutorEngine/Tests/TutorEngineTests/CoachPromptBuilderTests.swift`:

```swift
import XCTest
@testable import TutorEngine

final class CoachPromptBuilderTests: XCTestCase {
    func test_build_isSystemThenUser_withFactsAsBulletsAndTheDraft() {
        let request = CoachRequest(facts: ["Sınava kalan gün: 40", "Seri: 3 gün"], draft: "Sınavına 40 gün var.")
        let messages = CoachPromptBuilder.build(for: request)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], ChatPromptMessage(role: .system, text: CoachPromptBuilder.systemInstructions))
        XCTAssertEqual(messages[1], ChatPromptMessage(role: .user, text: """
        Öğrencinin durumu:
        - Sınava kalan gün: 40
        - Seri: 3 gün

        Taslak not:
        Sınavına 40 gün var.

        Bu taslağı aynı bilgileri koruyarak, daha kişisel ve cesaret verici bir dille yeniden yaz.
        """))
    }

    func test_systemInstructions_forbidNewNumbers_andAskForTurkish() {
        XCTAssertTrue(CoachPromptBuilder.systemInstructions.contains("Türkçe"))
        XCTAssertTrue(CoachPromptBuilder.systemInstructions.contains("yeni sayı"))
    }
}
```

`TutorEngine/Tests/TutorEngineTests/CoachNoteValidatorTests.swift`:

```swift
import XCTest
@testable import TutorEngine

final class CoachNoteValidatorTests: XCTestCase {
    let request = CoachRequest(facts: ["Sınava kalan gün: 40", "Günlük gereken yeni ders süresi: 12 dakika"], draft: "Sınavına 40 gün var.")

    func test_acceptsTextUsingOnlyKnownNumbers_andTrimsIt() {
        XCTAssertEqual(
            CoachNoteValidator.validate("  Sınavına 40 gün kaldı, günde 12 dakika yeter!\n", for: request),
            "Sınavına 40 gün kaldı, günde 12 dakika yeter!"
        )
    }

    func test_acceptsTextWithoutNumbers() {
        XCTAssertEqual(CoachNoteValidator.validate("Harika gidiyorsun.", for: request), "Harika gidiyorsun.")
    }

    func test_rejectsEmptyOrWhitespace() {
        XCTAssertNil(CoachNoteValidator.validate("   \n", for: request))
    }

    func test_rejectsTextLongerThan400Characters() {
        XCTAssertNil(CoachNoteValidator.validate(String(repeating: "a", count: 401), for: request))
        XCTAssertNotNil(CoachNoteValidator.validate(String(repeating: "a", count: 400), for: request))
    }

    func test_rejectsANumberThatIsNotInTheBriefing() {
        XCTAssertNil(CoachNoteValidator.validate("Sınavına 45 gün var.", for: request))
        XCTAssertNil(CoachNoteValidator.validate("Başarı oranın %90.", for: request))
    }
}
```

- [ ] **Step 2: Implement `CoachRequest.swift`**

```swift
import Foundation

/// Everything the model may use to write a coach note: fact lines computed by
/// the app, and the template text it should rewrite. The model never computes
/// numbers; `CoachNoteValidator` rejects any number that is not in here.
public struct CoachRequest: Sendable, Equatable {
    public let facts: [String]
    public let draft: String

    public init(facts: [String], draft: String) {
        self.facts = facts
        self.draft = draft
    }
}

/// Builds the coach prompt as native chat messages. Pure and deterministic.
public enum CoachPromptBuilder {
    public static let systemInstructions =
        "Sen, YDS'ye hazırlanan bir öğrencinin sıcak ve kısa konuşan çalışma koçusun. Her zaman Türkçe yaz ve öğrenciye \"sen\" diye hitap et. Yalnızca sana verilen bilgileri kullan; yeni sayı, tarih ya da yüzde uydurma. 2-4 kısa cümle yaz; liste ya da başlık kullanma."

    public static func build(for request: CoachRequest) -> [ChatPromptMessage] {
        let facts = request.facts.map { "- \($0)" }.joined(separator: "\n")
        let user = """
        Öğrencinin durumu:
        \(facts)

        Taslak not:
        \(request.draft)

        Bu taslağı aynı bilgileri koruyarak, daha kişisel ve cesaret verici bir dille yeniden yaz.
        """
        return [
            ChatPromptMessage(role: .system, text: systemInstructions),
            ChatPromptMessage(role: .user, text: user)
        ]
    }
}

/// Decides whether a model-written coach note may be shown.
public enum CoachNoteValidator {
    public static let maxCharacters = 400

    /// The trimmed note, or nil when it is empty, too long, or contains a
    /// number (a run of ASCII digits) that appears in neither the facts nor
    /// the draft.
    public static func validate(_ text: String, for request: CoachRequest) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxCharacters else { return nil }
        let allowed = numbers(in: request.draft + " " + request.facts.joined(separator: " "))
        guard numbers(in: trimmed).isSubset(of: allowed) else { return nil }
        return trimmed
    }

    static func numbers(in text: String) -> Set<String> {
        var result = Set<String>()
        var current = ""
        for character in text {
            if character.isASCII && character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                result.insert(current)
                current = ""
            }
        }
        if !current.isEmpty { result.insert(current) }
        return result
    }
}
```

- [ ] **Step 3: Extend the protocol and the MLX engine**

In `TutorRequest.swift` protocol:

```swift
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
    func respond(to chat: ChatRequest) async throws -> String
    func respond(to question: QuestionTutorRequest) async throws -> String
    func respond(to coach: CoachRequest) async throws -> String
}
```

In `MLXTutorEngine.swift`, move the role mapping out of `respond(to chat:)` into a shared helper and add the coach method:

```swift
    public func respond(to chat: ChatRequest) async throws -> String {
        try await respondToChatMessages(ChatPromptBuilder.build(for: chat))
    }

    public func respond(to coach: CoachRequest) async throws -> String {
        try await respondToChatMessages(CoachPromptBuilder.build(for: coach))
    }

    /// Native multi-turn input (`UserInput(chat:)`): the instructions go in
    /// the system role and earlier replies are real assistant turns rendered
    /// by the model's chat template.
    private func respondToChatMessages(_ prompt: [ChatPromptMessage]) async throws -> String {
        let messages: [Chat.Message] = prompt.map { message in
            switch message.role {
            case .system: return .system(message.text)
            case .user: return .user(message.text)
            case .assistant: return .assistant(message.text)
            }
        }
        let output = try await runGeneration(UserInput(chat: messages))
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
```

(Remove the old doc comment and body of `respond(to chat:)` that this replaces; keep `runGeneration` unchanged.)

- [ ] **Step 4: Add the stubs to every App test fake (same commit)**

In `App/Tests/EnglishAppTests/TutorViewModelTests.swift` `FakeTutorEngine`:

```swift
    func respond(to coach: CoachRequest) async throws -> String {
        fatalError("not used by TutorViewModelTests")
    }
```

In `App/Tests/EnglishAppTests/ChatViewModelTests.swift`, in both `FakeChatEngine` and `ControllableChatEngine`:

```swift
    func respond(to coach: CoachRequest) async throws -> String {
        fatalError("not used by ChatViewModelTests")
    }
```

- [ ] **Step 5: Commit, push, verify CI**

```bash
git add TutorEngine/Sources/TutorEngine/CoachRequest.swift TutorEngine/Sources/TutorEngine/TutorRequest.swift TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift TutorEngine/Tests/TutorEngineTests/CoachPromptBuilderTests.swift TutorEngine/Tests/TutorEngineTests/CoachNoteValidatorTests.swift App/Tests/EnglishAppTests/TutorViewModelTests.swift App/Tests/EnglishAppTests/ChatViewModelTests.swift
git commit -F - <<'EOF'
Add the coach prompt, note validator and engine method to TutorEngine

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: `Swift Tests` green (7 new TutorEngine tests); `App Build` green (the fakes compile).

---

### Task 4: Coach templates, note cache and CoachViewModel (App)

**Files:**
- Create: `App/Sources/EnglishApp/Coach/CoachMessageTemplates.swift`
- Create: `App/Sources/EnglishApp/Coach/CoachViewModel.swift`
- Create: `App/Sources/EnglishApp/Tutor/TutorTimeout.swift`
- Modify: `App/Sources/EnglishApp/Tutor/TutorViewModel.swift` (use the shared timeout helper; move `TutorTimeoutError` out)
- Modify: `App/Sources/EnglishApp/AppState.swift` (add `coachNoteCache`)
- Test: `App/Tests/EnglishAppTests/CoachMessageTemplatesTests.swift`, `App/Tests/EnglishAppTests/CoachViewModelTests.swift`

New files under `App/Sources/EnglishApp/` are picked up by XcodeGen's recursive `sources:` scan; no `project.yml` change.

**Interfaces:**
- Consumes: `CoachPlan`, `CoachBriefing`, `CoachStatus`, `CoachMode` (Task 1); `CoachRequest`, `CoachNoteValidator` (Task 3); `Skill.displayName` (existing, App).
- Produces: `CoachMessageTemplates.message(for: CoachBriefing) -> String`, `.badge(for: CoachStatus) -> String`, `.progressLine(for: CoachPlan) -> String`, `.lockedLine(for: CoachPlan) -> String?`, `.facts(for: CoachBriefing) -> [String]`, `.request(for: CoachBriefing) -> CoachRequest`, `.needsExamDateInvite(_ plan: CoachPlan) -> Bool`; `CoachNoteCache` (`@MainActor final class`, `note(forKey:)`, `store(_:forKey:)`, `static key(day:draft:)`); `CoachViewModel` (`@MainActor @Observable`) with `text`, `source` (`.template`/`.model`), `isGenerating`, `init(cache:timeoutSeconds:engineProvider:)`, `show(_:day:)`, `requestPersonalNote() async`; `func withTutorTimeout(nanoseconds: UInt64, _ work: @escaping @Sendable () async throws -> String) async throws -> String`; `AppState.coachNoteCache`.

- [ ] **Step 1: Extract the timeout helper (no behaviour change)**

Create `App/Sources/EnglishApp/Tutor/TutorTimeout.swift` containing the existing `TutorTimeoutError` struct moved verbatim from `TutorViewModel.swift` (with its doc comment) plus:

```swift
/// Runs `work`, throwing `TutorTimeoutError` if it has not finished after
/// `nanoseconds`. Shared by every tutor/coach request; see the caveat on
/// `TutorTimeoutError` about engines that ignore cancellation.
func withTutorTimeout(nanoseconds: UInt64, _ work: @escaping @Sendable () async throws -> String) async throws -> String {
    try await withThrowingTaskGroup(of: String.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw TutorTimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else {
            throw TutorTimeoutError()
        }
        return result
    }
}
```

In `TutorViewModel.swift`: delete the `TutorTimeoutError` struct and the private `withTimeout` method; replace both `try await withTimeout { ... }` calls with `try await withTutorTimeout(nanoseconds: timeoutNanoseconds) { ... }` (same closures). The existing `TutorViewModelTests` cover this path unchanged.

- [ ] **Step 2: Write the failing template tests**

`App/Tests/EnglishAppTests/CoachMessageTemplatesTests.swift`:

```swift
import XCTest
import LearningEngine
@testable import EnglishApp

final class CoachMessageTemplatesTests: XCTestCase {
    func plan(
        _ status: CoachStatus, mode: CoachMode = .examDate, daysToExam: Int? = 40,
        remaining: Int = 120, share: Double = 0.38, locked: Int = 0, pace: Int = 4,
        weakest: Skill? = nil
    ) -> CoachPlan {
        CoachPlan(
            status: status, mode: mode, daysToExam: daysToExam, targetFinishDay: nil,
            daysToTargetFinish: 33, remainingMinutes: remaining, completedShare: share,
            lockedLessonCount: locked, requiredMinutesPerDay: pace, weakestSkill: weakest,
            directive: CoachDirective(extraLessonMinutes: 0, reviewOnly: false)
        )
    }

    func briefing(_ plan: CoachPlan) -> CoachBriefing {
        CoachBriefing(plan: plan, weekDaysStudied: 4, weekMinutes: 55, weekLessonsCompleted: 3, streak: 2)
    }

    func test_onTrack_examMode() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack))),
            "Sınavına 40 gün var ve planındasın. Günde yaklaşık 4 dakika yeni dersle devam."
        )
    }

    func test_onTrack_freePace_invitesAnExamDate() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10))),
            "Kendi temponda düzenli ilerliyorsun. Günde yaklaşık 10 dakika yeni dersle devam. Sınav tarihini eklersen programını ona göre kurarım."
        )
    }

    func test_behind_ahead_finalWeek_unreachable() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.behind(days: 3)))),
            "Plana göre 3 gün gerideyiz. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersek yetişiriz."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.ahead(days: 2)))),
            "Planın 2 gün önündesin, harika gidiyorsun! Bu tempoyu korursan hedefine erken ulaşırsın."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.finalWeek, daysToExam: 5, pace: 0))),
            "Sınavına 5 gün kaldı. Bu hafta yeni ders yok: tekrarlara ve zorlandığın konulara odaklan."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.unreachable(shortfallMinutesPerDay: 20), daysToExam: 12, pace: 40))),
            "Sınavına 12 gün kaldı ve kalan dersler için günde 40 dakika gerekiyor; bu, günlük sürenden 20 dakika fazla. Günlük süreni artırabilir ya da sınav tarihini gözden geçirebilirsin."
        )
    }

    func test_noData_scopeComplete_examPassed() {
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.noData))),
            "Sınavına 40 gün var. Kalan 120 dakikalık ders için günde yaklaşık 4 dakika yeterli. İlk dersinle başlayalım."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.scopeComplete, mode: .freePace, daysToExam: nil, remaining: 0, pace: 0))),
            "Açık olan bütün dersleri bitirdin. Şimdi tekrarlarla bildiklerini sağlamlaştırma zamanı."
        )
        XCTAssertEqual(
            CoachMessageTemplates.message(for: briefing(plan(.examPassed, mode: .freePace, daysToExam: 0, pace: 10))),
            "Sınav tarihin geçmiş görünüyor. Yeni bir tarih eklersen programını ona göre kurarım; o zamana kadar kendi temponla devam ediyoruz."
        )
    }

    func test_badges() {
        XCTAssertEqual(CoachMessageTemplates.badge(for: .onTrack), "Yoldasın")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .behind(days: 3)), "3 gün geridesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .ahead(days: 2)), "2 gün öndesin")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .finalWeek), "Son hafta: tekrar")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .scopeComplete), "Kapsam tamam")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .unreachable(shortfallMinutesPerDay: 5)), "Tempo yetmiyor")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .examPassed), "Tarih geçti")
        XCTAssertEqual(CoachMessageTemplates.badge(for: .noData), "Başlangıç")
    }

    func test_progressAndLockedLines() {
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack)), "Sınava 40 gün · ilerleme %38 · günde ~4 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.onTrack, mode: .freePace, daysToExam: nil, pace: 10)), "İlerleme %38 · günde ~10 dk yeni ders")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.finalWeek, daysToExam: 5, pace: 0)), "Sınava 5 gün · ilerleme %38 · sadece tekrar")
        XCTAssertEqual(CoachMessageTemplates.progressLine(for: plan(.scopeComplete, share: 1)), "İlerleme %100 · açık dersler bitti")
        XCTAssertEqual(CoachMessageTemplates.lockedLine(for: plan(.onTrack, locked: 99)), "Paketin 99 dersi kilitli; açtığında programın güncellenir.")
        XCTAssertNil(CoachMessageTemplates.lockedLine(for: plan(.onTrack)))
    }

    func test_facts_andRequest() {
        let b = briefing(plan(.onTrack, weakest: .grammar))
        XCTAssertEqual(CoachMessageTemplates.facts(for: b), [
            "Durum: Yoldasın",
            "İlerleme: %38",
            "Kalan ders süresi: 120 dakika",
            "Sınava kalan gün: 40",
            "Günlük gereken yeni ders süresi: 4 dakika",
            "Son 7 günde çalışılan gün: 4",
            "Son 7 günde biten ders: 3",
            "Seri: 2 gün",
            "Bu hafta en çok ihtiyaç duyulan beceri: Gramer"
        ])
        let request = CoachMessageTemplates.request(for: b)
        XCTAssertEqual(request.draft, CoachMessageTemplates.message(for: b))
        XCTAssertEqual(request.facts, CoachMessageTemplates.facts(for: b))
    }

    func test_examDateInvite() {
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack, mode: .freePace, daysToExam: nil)))
        XCTAssertTrue(CoachMessageTemplates.needsExamDateInvite(plan(.examPassed, mode: .freePace, daysToExam: -2)))
        XCTAssertFalse(CoachMessageTemplates.needsExamDateInvite(plan(.onTrack)))
    }
}
```

- [ ] **Step 3: Implement the templates**

`App/Sources/EnglishApp/Coach/CoachMessageTemplates.swift`:

```swift
import Foundation
import LearningEngine
import TutorEngine

/// Deterministic Turkish coach texts. Always available; a model note only
/// ever replaces `message(for:)` after validation.
enum CoachMessageTemplates {
    static func message(for briefing: CoachBriefing) -> String {
        let plan = briefing.plan
        let days = plan.daysToExam ?? 0
        let pace = plan.requiredMinutesPerDay
        var text: String
        switch plan.status {
        case .scopeComplete:
            text = "Açık olan bütün dersleri bitirdin. Şimdi tekrarlarla bildiklerini sağlamlaştırma zamanı."
        case .examPassed:
            text = "Sınav tarihin geçmiş görünüyor. Yeni bir tarih eklersen programını ona göre kurarım; o zamana kadar kendi temponla devam ediyoruz."
        case .finalWeek:
            text = "Sınavına \(days) gün kaldı. Bu hafta yeni ders yok: tekrarlara ve zorlandığın konulara odaklan."
        case .unreachable(let shortfall):
            text = "Sınavına \(days) gün kaldı ve kalan dersler için günde \(pace) dakika gerekiyor; bu, günlük sürenden \(shortfall) dakika fazla. Günlük süreni artırabilir ya da sınav tarihini gözden geçirebilirsin."
        case .noData:
            text = plan.mode == .examDate
                ? "Sınavına \(days) gün var. Kalan \(plan.remainingMinutes) dakikalık ders için günde yaklaşık \(pace) dakika yeterli. İlk dersinle başlayalım."
                : "Kendi temponla, günde yaklaşık \(pace) dakika yeni dersle ilerleyeceğiz. İlk dersinle başlayalım."
        case .behind(let n):
            text = "Plana göre \(n) gün gerideyiz. Bugünkü plana birkaç ek ders koydum; birkaç gün böyle devam edersek yetişiriz."
        case .ahead(let n):
            text = "Planın \(n) gün önündesin, harika gidiyorsun! Bu tempoyu korursan hedefine erken ulaşırsın."
        case .onTrack:
            text = plan.mode == .examDate
                ? "Sınavına \(days) gün var ve planındasın. Günde yaklaşık \(pace) dakika yeni dersle devam."
                : "Kendi temponda düzenli ilerliyorsun. Günde yaklaşık \(pace) dakika yeni dersle devam."
        }
        if plan.daysToExam == nil && plan.status != .scopeComplete {
            text += " Sınav tarihini eklersen programını ona göre kurarım."
        }
        return text
    }

    static func badge(for status: CoachStatus) -> String {
        switch status {
        case .scopeComplete: return "Kapsam tamam"
        case .examPassed: return "Tarih geçti"
        case .finalWeek: return "Son hafta: tekrar"
        case .unreachable: return "Tempo yetmiyor"
        case .noData: return "Başlangıç"
        case .behind(let n): return "\(n) gün geridesin"
        case .ahead(let n): return "\(n) gün öndesin"
        case .onTrack: return "Yoldasın"
        }
    }

    static func progressLine(for plan: CoachPlan) -> String {
        let percent = Int((plan.completedShare * 100).rounded())
        switch plan.status {
        case .scopeComplete:
            return "İlerleme %\(percent) · açık dersler bitti"
        case .finalWeek:
            return "Sınava \(plan.daysToExam ?? 0) gün · ilerleme %\(percent) · sadece tekrar"
        default:
            if plan.mode == .examDate, let days = plan.daysToExam {
                return "Sınava \(days) gün · ilerleme %\(percent) · günde ~\(plan.requiredMinutesPerDay) dk yeni ders"
            }
            return "İlerleme %\(percent) · günde ~\(plan.requiredMinutesPerDay) dk yeni ders"
        }
    }

    static func lockedLine(for plan: CoachPlan) -> String? {
        guard plan.lockedLessonCount > 0 else { return nil }
        return "Paketin \(plan.lockedLessonCount) dersi kilitli; açtığında programın güncellenir."
    }

    /// True when the card should invite the learner to add or change an exam date.
    static func needsExamDateInvite(_ plan: CoachPlan) -> Bool {
        plan.daysToExam == nil || plan.status == .examPassed
    }

    static func facts(for briefing: CoachBriefing) -> [String] {
        let plan = briefing.plan
        var facts = [
            "Durum: \(badge(for: plan.status))",
            "İlerleme: %\(Int((plan.completedShare * 100).rounded()))",
            "Kalan ders süresi: \(plan.remainingMinutes) dakika"
        ]
        if let days = plan.daysToExam, days > 0 { facts.append("Sınava kalan gün: \(days)") }
        if plan.requiredMinutesPerDay > 0 { facts.append("Günlük gereken yeni ders süresi: \(plan.requiredMinutesPerDay) dakika") }
        facts.append("Son 7 günde çalışılan gün: \(briefing.weekDaysStudied)")
        facts.append("Son 7 günde biten ders: \(briefing.weekLessonsCompleted)")
        facts.append("Seri: \(briefing.streak) gün")
        if let skill = plan.weakestSkill { facts.append("Bu hafta en çok ihtiyaç duyulan beceri: \(skill.displayName)") }
        return facts
    }

    static func request(for briefing: CoachBriefing) -> CoachRequest {
        CoachRequest(facts: facts(for: briefing), draft: message(for: briefing))
    }
}
```

- [ ] **Step 4: Write the failing view-model tests**

`App/Tests/EnglishAppTests/CoachViewModelTests.swift`:

```swift
import XCTest
import LearningEngine
import TutorEngine
@testable import EnglishApp

private final class FakeCoachEngine: TutorEngine {
    var reply = "Harika gidiyorsun, sınavına 40 gün var."
    var error: Error?
    var delayNanoseconds: UInt64 = 0
    private(set) var coachRequests: [CoachRequest] = []

    func respond(to request: TutorRequest) async throws -> String { fatalError("not used by CoachViewModelTests") }
    func respond(to chat: ChatRequest) async throws -> String { fatalError("not used by CoachViewModelTests") }
    func respond(to question: QuestionTutorRequest) async throws -> String { fatalError("not used by CoachViewModelTests") }
    func respond(to coach: CoachRequest) async throws -> String {
        coachRequests.append(coach)
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        if let error { throw error }
        return reply
    }
}

private struct StubError: Error {}

@MainActor
final class CoachViewModelTests: XCTestCase {
    let day = Date(timeIntervalSince1970: 1_800_000_000)

    func briefing(_ status: CoachStatus = .onTrack) -> CoachBriefing {
        CoachBriefing(
            plan: CoachPlan(
                status: status, mode: .examDate, daysToExam: 40, targetFinishDay: nil,
                daysToTargetFinish: 33, remainingMinutes: 120, completedShare: 0.38,
                lockedLessonCount: 0, requiredMinutesPerDay: 4, weakestSkill: nil,
                directive: CoachDirective(extraLessonMinutes: 0, reviewOnly: false)
            ),
            weekDaysStudied: 4, weekMinutes: 55, weekLessonsCompleted: 3, streak: 2
        )
    }

    func makeViewModel(engine: FakeCoachEngine?, cache: CoachNoteCache = CoachNoteCache(), timeoutSeconds: UInt64 = 30) -> CoachViewModel {
        CoachViewModel(cache: cache, timeoutSeconds: timeoutSeconds) { engine as (any TutorEngine)? }
    }

    func test_show_displaysTheTemplate() {
        let vm = makeViewModel(engine: FakeCoachEngine())
        vm.show(briefing(), day: day)
        XCTAssertEqual(vm.text, CoachMessageTemplates.message(for: briefing()))
        XCTAssertEqual(vm.source, .template)
    }

    func test_requestPersonalNote_validReply_replacesTheTemplate_andIsCachedForTheDay() async {
        let cache = CoachNoteCache()
        let engine = FakeCoachEngine()
        let vm = makeViewModel(engine: engine, cache: cache)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        XCTAssertEqual(vm.text, "Harika gidiyorsun, sınavına 40 gün var.")
        XCTAssertEqual(vm.source, .model)
        XCTAssertFalse(vm.isGenerating)
        XCTAssertEqual(engine.coachRequests, [CoachMessageTemplates.request(for: briefing())])

        let second = makeViewModel(engine: FakeCoachEngine(), cache: cache)
        second.show(briefing(), day: day)
        XCTAssertEqual(second.text, "Harika gidiyorsun, sınavına 40 gün var.")
        XCTAssertEqual(second.source, .model)
    }

    func test_cachedNote_isIgnored_whenTheTemplateChanged() async {
        let cache = CoachNoteCache()
        let vm = makeViewModel(engine: FakeCoachEngine(), cache: cache)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        vm.show(briefing(.behind(days: 3)), day: day)
        XCTAssertEqual(vm.source, .template)
        XCTAssertEqual(vm.text, CoachMessageTemplates.message(for: briefing(.behind(days: 3))))
    }

    func test_requestPersonalNote_noEngine_keepsTemplate() async {
        let vm = makeViewModel(engine: nil)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        XCTAssertEqual(vm.source, .template)
        XCTAssertFalse(vm.isGenerating)
    }

    func test_requestPersonalNote_foreignNumber_keepsTemplate() async {
        let engine = FakeCoachEngine()
        engine.reply = "Sınavına 45 gün var."
        let vm = makeViewModel(engine: engine)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        XCTAssertEqual(vm.source, .template)
    }

    func test_requestPersonalNote_error_keepsTemplate() async {
        let engine = FakeCoachEngine()
        engine.error = StubError()
        let vm = makeViewModel(engine: engine)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        XCTAssertEqual(vm.source, .template)
    }

    func test_requestPersonalNote_timeout_keepsTemplate() async {
        let engine = FakeCoachEngine()
        engine.delayNanoseconds = 3_000_000_000
        let vm = makeViewModel(engine: engine, timeoutSeconds: 1)
        vm.show(briefing(), day: day)
        await vm.requestPersonalNote()
        XCTAssertEqual(vm.source, .template)
        XCTAssertFalse(vm.isGenerating)
    }
}
```

- [ ] **Step 5: Implement the cache and the view model**

`App/Sources/EnglishApp/Coach/CoachViewModel.swift`:

```swift
import Foundation
import LearningEngine
import TutorEngine

/// Model-written coach notes for the running app session, keyed by day and
/// template text, so a note is reused the same day but never for a changed status.
@MainActor
final class CoachNoteCache {
    private var notes: [String: String] = [:]

    func note(forKey key: String) -> String? { notes[key] }
    func store(_ note: String, forKey key: String) { notes[key] = note }

    static func key(day: Date, draft: String) -> String {
        "\(Int(day.timeIntervalSince1970))|\(draft)"
    }
}

@MainActor
@Observable
final class CoachViewModel {
    enum Source: Equatable { case template, model }

    private(set) var text = ""
    private(set) var source: Source = .template
    private(set) var isGenerating = false

    @ObservationIgnored private var request: CoachRequest?
    @ObservationIgnored private var cacheKey: String?
    @ObservationIgnored private let cache: CoachNoteCache
    @ObservationIgnored private let timeoutNanoseconds: UInt64
    @ObservationIgnored private let engineProvider: @MainActor () async -> (any TutorEngine)?

    init(cache: CoachNoteCache, timeoutSeconds: UInt64 = 30, engineProvider: @escaping @MainActor () async -> (any TutorEngine)?) {
        self.cache = cache
        self.timeoutNanoseconds = timeoutSeconds * 1_000_000_000
        self.engineProvider = engineProvider
    }

    /// Shows today's cached model note for this exact template, else the template.
    func show(_ briefing: CoachBriefing, day: Date) {
        let request = CoachMessageTemplates.request(for: briefing)
        let key = CoachNoteCache.key(day: day, draft: request.draft)
        self.request = request
        cacheKey = key
        if let cached = cache.note(forKey: key) {
            text = cached
            source = .model
        } else {
            text = request.draft
            source = .template
        }
    }

    /// Asks the on-device model for a personal note. Any failure — no engine,
    /// error, timeout, or a reply the validator rejects — keeps the template.
    func requestPersonalNote() async {
        guard let request, let key = cacheKey, source == .template, !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        guard let engine = await engineProvider() else { return }
        let reply = try? await withTutorTimeout(nanoseconds: timeoutNanoseconds) {
            try await engine.respond(to: request)
        }
        guard let reply, let note = CoachNoteValidator.validate(reply, for: request) else { return }
        cache.store(note, forKey: key)
        // The learner may have finished a lesson meanwhile; only show a note
        // written for the template that is still on screen.
        guard key == cacheKey else { return }
        text = note
        source = .model
    }
}
```

In `AppState` add, next to the other `@ObservationIgnored let` properties:

```swift
    @ObservationIgnored let coachNoteCache = CoachNoteCache()
```

- [ ] **Step 6: Commit, push, verify CI**

```bash
git add App/Sources/EnglishApp/Coach App/Sources/EnglishApp/Tutor/TutorTimeout.swift App/Sources/EnglishApp/Tutor/TutorViewModel.swift App/Sources/EnglishApp/AppState.swift App/Tests/EnglishAppTests/CoachMessageTemplatesTests.swift App/Tests/EnglishAppTests/CoachViewModelTests.swift
git commit -F - <<'EOF'
Add Turkish coach templates and the coach note view model

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: `App Build` green with the 8 template tests, 7 view-model tests and all existing `TutorViewModelTests`.

---

### Task 5: TodayPlanCoordinator builds the coach briefing and directive

**Files:**
- Modify: `App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift`
- Test: `App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift` (append)

**Interfaces:**
- Consumes: `CoachPlanner`, `CoachInput`, `CoachBriefing` (Task 1); `DailyPlanInput(coach:)` (Task 2).
- Produces: `TodayPlanCoordinator.init(..., isPremium: Bool = false)` (new last parameter with default, so existing call sites compile unchanged); `buildPlanInput()` sets `coach` only when `isPremium`; `func buildCoachBriefing() throws -> CoachBriefing?` (nil only when there is no profile/package; independent of `isPremium`).

- [ ] **Step 1: Write the failing tests** (append to `TodayPlanCoordinatorTests`; add a helper)

```swift
    func premiumCoordinator(_ context: ModelContext, level: PackageAccessLevel = .preview) -> TodayPlanCoordinator {
        TodayPlanCoordinator(context: context, userID: userID, accessProvider: FixedAccessProvider(level: level), now: now, calendar: calendar, isPremium: true)
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
```

- [ ] **Step 2: Implement**

In `TodayPlanCoordinator`:

1. Add `let isPremium: Bool` and the init parameter:

```swift
    init(context: ModelContext, userID: String, accessProvider: any PackageAccessProvider, now: Date = Date(), calendar: Calendar = .current, isPremium: Bool = false) {
        self.context = context
        self.userID = userID
        self.accessProvider = accessProvider
        self.now = now
        self.calendar = calendar
        self.isPremium = isPremium
    }
```

2. Factor the shared snapshot out of `buildPlanInput()` so plan and briefing read the same data:

```swift
    private struct PathSnapshot {
        let profile: LearnerProfile
        let package: ContentPackage
        let lessons: [Lesson]
        let planLessons: [PlanLesson]
        let startOfToday: Date
        let pastWeekSkillMinutes: [Skill: Double]
    }

    private func pathSnapshot() throws -> PathSnapshot? {
        guard let profile = try ensureProfile(), let package = try activePackage() else { return nil }
        let units = package.units.sorted { $0.order < $1.order }
        let lessons = units.flatMap { $0.lessons.sorted { $0.order < $1.order } }
        let outline = PackageOutline(units: units.map { unit in
            UnitOutline(id: unit.id, order: unit.order, lessonIDs: unit.lessons.map(\.id))
        })
        let accessible = LessonAccessPolicy().accessibleLessonIDs(in: outline, level: accessProvider.accessLevel(forPackageID: package.id))
        let completion = try completionDates()
        let planLessons = lessons.map { lesson in
            PlanLesson(
                id: lesson.id, title: lesson.title, skill: lesson.skill,
                estimatedMinutes: lesson.estimatedDurationMinutes,
                isAccessible: accessible.contains(lesson.id),
                completedAt: completion[lesson.id]
            )
        }
        let startOfToday = calendar.startOfDay(for: now)
        return PathSnapshot(
            profile: profile, package: package, lessons: lessons, planLessons: planLessons,
            startOfToday: startOfToday,
            pastWeekSkillMinutes: try pastWeekSkillMinutes(startOfToday: startOfToday, lessons: lessons)
        )
    }

    private func coachPlan(_ snapshot: PathSnapshot) -> CoachPlan {
        CoachPlanner(calendar: calendar).plan(CoachInput(
            startOfToday: snapshot.startOfToday,
            examDate: snapshot.profile.examDate,
            dailyMinutes: snapshot.profile.dailyMinutes,
            profileCreatedAt: snapshot.profile.createdAt,
            lessonsInPathOrder: snapshot.planLessons,
            weights: snapshot.package.skillWeights,
            pastWeekSkillMinutes: snapshot.pastWeekSkillMinutes
        ))
    }
```

3. Rewrite the beginning of `buildPlanInput()` to use it (the review/practice part is unchanged):

```swift
    func buildPlanInput() throws -> DailyPlanInput? {
        guard let snapshot = try pathSnapshot() else { return nil }
        let startOfToday = snapshot.startOfToday
        // ... existing userIDValue / nowValue / existingItemIDs / practiceIndex /
        //     dueNowRows / todaysLogs / reviewedTodayIDs / dueVocabularyRows /
        //     dueNowCount / reviewedTodayCount / duePracticeCards code, unchanged ...

        return DailyPlanInput(
            weights: snapshot.package.skillWeights,
            dailyMinutes: snapshot.profile.dailyMinutes,
            lessonsInPathOrder: snapshot.planLessons,
            dueNowCount: dueNowCount,
            reviewedTodayCount: reviewedTodayCount,
            pastWeekSkillMinutes: snapshot.pastWeekSkillMinutes,
            startOfToday: startOfToday,
            duePracticeCards: duePracticeCards,
            coach: isPremium ? coachPlan(snapshot).directive : nil
        )
    }
```

4. Add the briefing:

```swift
    /// The coach's view of today. Independent of premium: the view decides
    /// whether to show it or a locked teaser.
    func buildCoachBriefing() throws -> CoachBriefing? {
        guard let snapshot = try pathSnapshot() else { return nil }
        let plan = coachPlan(snapshot)
        guard let weekStart = calendar.date(byAdding: .day, value: -7, to: snapshot.startOfToday) else { return nil }
        let userIDValue = userID
        let today = snapshot.startOfToday
        let weekLogs = try context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate {
            $0.userID == userIDValue && $0.reviewedAt >= weekStart && $0.reviewedAt < today
        }))
        let weekCompletions = try completionDates().values.filter { $0 >= weekStart && $0 < today }
        let studiedDays = Set((weekLogs.map(\.reviewedAt) + weekCompletions).map { calendar.startOfDay(for: $0) })
        return CoachBriefing(
            plan: plan,
            weekDaysStudied: studiedDays.count,
            weekMinutes: Int(snapshot.pastWeekSkillMinutes.values.reduce(0, +).rounded()),
            weekLessonsCompleted: weekCompletions.count,
            streak: try streak()
        )
    }
```

Note on `test_coachBriefing_...weekMinutes`: `pastWeekSkillMinutes` counts only review logs whose item exists (item-u0-l1-i0/i1 exist in `TestPackageJSON`) → 8 + 0.8 = 8.8 → 9.

- [ ] **Step 3: Commit, push, verify CI**

```bash
git add App/Sources/EnglishApp/Today/TodayPlanCoordinator.swift App/Tests/EnglishAppTests/TodayPlanCoordinatorTests.swift
git commit -F - <<'EOF'
Feed the coach directive into premium daily plans and build the coach briefing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: `App Build` green; all existing `TodayPlanCoordinatorTests` still pass (default `isPremium: false`).

---

### Task 6: Coach UI — Today card, study settings sheet, Profile section, paywall line

**Files:**
- Create: `App/Sources/EnglishApp/Coach/CoachCardView.swift`
- Create: `App/Sources/EnglishApp/Profile/StudySettingsSheet.swift`
- Modify: `App/Sources/EnglishApp/Today/TodayPlanView.swift`
- Modify: `App/Sources/EnglishApp/DesignSystem/PlanTaskRow.swift`
- Modify: `App/Sources/EnglishApp/Profile/ProfileView.swift`
- Modify: `App/Sources/EnglishApp/Store/PaywallView.swift`
- Modify: `docs/store-setup.md` (TestFlight checklist)
- Test: `App/Tests/EnglishAppTests/StudySettingsTests.swift`

**Interfaces:**
- Consumes: `CoachViewModel`, `CoachMessageTemplates`, `AppState.coachNoteCache` (Task 4); `TodayPlanCoordinator(isPremium:)`, `buildCoachBriefing()` (Task 5); `DailyPlan.coachAddedLessonIDs` (Task 2); `AppState.tutorAccess`, `loadTutorEngineIfNeeded()`, `tutorEngine`, `premiumProvider`, `bumpDataGeneration()` (existing); `PaywallMode.premium` (existing).
- Produces: `StudySettings.dailyMinutesRange = 10...60`, `StudySettings.dailyMinutesStep = 5`, `StudySettings.save(dailyMinutes:examDate:userID:context:calendar:) throws` (`calendar` defaults to `.current`); `PlanTaskRow(task:isHighlighted:isCoachAdded:onStart:)` (`isCoachAdded` defaults to `false`).

- [ ] **Step 1: Write the failing settings test**

`App/Tests/EnglishAppTests/StudySettingsTests.swift`:

```swift
import XCTest
import SwiftData
import LearningEngine
@testable import EnglishApp

@MainActor
final class StudySettingsTests: XCTestCase {
    func test_save_clampsDailyMinutes_andStoresTheExamDateAtStartOfDay() throws {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        context.insert(LearnerProfile(userID: "u", activePackageID: "pkg", createdAt: Date()))
        try context.save()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let exam = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 15))!

        try StudySettings.save(dailyMinutes: 75, examDate: exam, userID: "u", context: context, calendar: calendar)
        var profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 60)
        XCTAssertEqual(profile.examDate, calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))

        try StudySettings.save(dailyMinutes: 5, examDate: nil, userID: "u", context: context, calendar: calendar)
        profile = try XCTUnwrap(context.fetch(FetchDescriptor<LearnerProfile>()).first)
        XCTAssertEqual(profile.dailyMinutes, 10)
        XCTAssertNil(profile.examDate)
    }
}
```

- [ ] **Step 2: Implement the settings sheet**

`App/Sources/EnglishApp/Profile/StudySettingsSheet.swift`:

```swift
import SwiftUI
import SwiftData
import LearningEngine

enum StudySettings {
    static let dailyMinutesRange = 10...60
    static let dailyMinutesStep = 5

    /// Writes the learner's daily minutes (clamped to the onboarding range) and
    /// exam date (start of day, or nil) to their profile.
    static func save(dailyMinutes: Int, examDate: Date?, userID: String, context: ModelContext, calendar: Calendar = .current) throws {
        let userIDValue = userID
        guard let profile = try context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userIDValue })).first else { return }
        profile.dailyMinutes = min(max(dailyMinutes, dailyMinutesRange.lowerBound), dailyMinutesRange.upperBound)
        profile.examDate = examDate.map { calendar.startOfDay(for: $0) }
        try context.save()
    }
}

struct StudySettingsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var dailyMinutes = LearnerProfile.defaultDailyMinutes
    @State private var hasExamDate = false
    @State private var examDate = Date()
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Günlük süre") {
                    Stepper("Günlük \(dailyMinutes) dakika", value: $dailyMinutes, in: StudySettings.dailyMinutesRange, step: StudySettings.dailyMinutesStep)
                }
                Section("Sınav tarihi") {
                    Toggle("Bir sınav tarihim var", isOn: $hasExamDate).tint(Theme.primary)
                    if hasExamDate {
                        DatePicker("Sınav tarihi", selection: $examDate, in: Date()..., displayedComponents: .date)
                    }
                }
                if let saveError {
                    Text(saveError).font(.footnote).foregroundStyle(Theme.danger)
                }
            }
            .navigationTitle("Çalışma ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet", action: save) }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let userID = UserIdentity.current
        guard let profile = try? context.fetch(FetchDescriptor<LearnerProfile>(predicate: #Predicate { $0.userID == userID })).first else { return }
        dailyMinutes = profile.dailyMinutes
        hasExamDate = profile.examDate != nil
        examDate = profile.examDate ?? Date()
    }

    private func save() {
        do {
            try StudySettings.save(dailyMinutes: dailyMinutes, examDate: hasExamDate ? examDate : nil, userID: UserIdentity.current, context: context)
            appState.bumpDataGeneration()
            dismiss()
        } catch {
            saveError = "Ayarlar kaydedilemedi. Lütfen tekrar dene."
        }
    }
}
```

- [ ] **Step 3: Coach card**

`App/Sources/EnglishApp/Coach/CoachCardView.swift`:

```swift
import SwiftUI
import LearningEngine

/// Premium coach card at the top of Today. Free learners get `CoachTeaserCard`.
struct CoachCardView: View {
    let briefing: CoachBriefing
    let viewModel: CoachViewModel
    let canAskModel: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        let plan = briefing.plan
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Koçun", systemImage: "figure.run.circle")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.primary)
                    Spacer()
                    Text(CoachMessageTemplates.badge(for: plan.status))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Text(viewModel.text)
                    .font(.subheadline).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(CoachMessageTemplates.progressLine(for: plan))
                    .font(.footnote.monospacedDigit()).foregroundStyle(Theme.secondaryInk)
                ProgressBar(progress: plan.completedShare)
                if let locked = CoachMessageTemplates.lockedLine(for: plan) {
                    Text(locked).font(.caption).foregroundStyle(Theme.secondaryInk)
                }
                if case .unreachable = plan.status {
                    HStack {
                        Button("Günlük süreyi artır", action: onOpenSettings)
                        Spacer()
                        Button("Sınav tarihini değiştir", action: onOpenSettings)
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                } else if CoachMessageTemplates.needsExamDateInvite(plan) {
                    Button("Sınav tarihini ekle, programını kurayım", action: onOpenSettings)
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                }
                if canAskModel && viewModel.source == .template {
                    Button {
                        Task { await viewModel.requestPersonalNote() }
                    } label: {
                        if viewModel.isGenerating {
                            HStack(spacing: 6) { ProgressView(); Text("Koçun yazıyor...") }
                        } else {
                            Label("Koçtan kişisel not al", systemImage: "sparkles")
                        }
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.primary)
                    .disabled(viewModel.isGenerating)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct CoachTeaserCard: View {
    let onUpgrade: () -> Void

    var body: some View {
        Button(action: onUpgrade) {
            PaperCard {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill").foregroundStyle(Theme.secondaryInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Koç").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                        Text("Sınav tarihine göre kişisel program").font(.caption).foregroundStyle(Theme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.secondaryInk)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("AI Koç, kilitli. Sınav tarihine göre kişisel program. AI Premium'a geçmek için dokun.")
    }
}
```

- [ ] **Step 4: Tag coach-added tasks in `PlanTaskRow`**

Add a defaulted stored property after `isHighlighted`. The memberwise init becomes `PlanTaskRow(task:isHighlighted:isCoachAdded:onStart:)` with `isCoachAdded` optional, so every existing `PlanTaskRow(task:isHighlighted:) { ... }` call compiles unchanged:

```swift
struct PlanTaskRow: View {
    let task: PlanTask
    let isHighlighted: Bool
    var isCoachAdded: Bool = false
    let onStart: () -> Void
```

In the body, directly under the subtitle `Text(PlanTaskText.subtitle(task))` view, add:

```swift
                    if isCoachAdded {
                        Text("Koç ekledi")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
```

- [ ] **Step 5: Wire Today**

In `TodayPlanView`:

1. New state:

```swift
    @State private var coachBriefing: CoachBriefing?
    @State private var coachViewModel: CoachViewModel?
    @State private var showStudySettings = false
    @State private var paywall: PaywallMode?
```

2. Modifiers (next to the existing `.fullScreenCover`):

```swift
        .sheet(isPresented: $showStudySettings) { StudySettingsSheet() }
        .sheet(item: $paywall) { mode in PaywallView(mode: mode, store: appState.entitlements) }
```

3. In `planContent`, directly after the `Text("Bugünün planı")` line:

```swift
            coachSection
```

and add:

```swift
    @ViewBuilder
    private var coachSection: some View {
        if let coachBriefing {
            if appState.premiumProvider.isPremium, let coachViewModel {
                CoachCardView(
                    briefing: coachBriefing,
                    viewModel: coachViewModel,
                    canAskModel: appState.tutorAccess == .allowed,
                    onOpenSettings: { showStudySettings = true }
                )
            } else if !appState.premiumProvider.isPremium {
                CoachTeaserCard { paywall = .premium }
            }
        }
    }
```

4. In the `ForEach` over tasks, pass the tag:

```swift
                PlanTaskRow(task: task, isHighlighted: index == highlightIndex, isCoachAdded: isCoachAdded(task, plan)) { handle(task) }
```

with

```swift
    private func isCoachAdded(_ task: PlanTask, _ plan: DailyPlan) -> Bool {
        if case .lesson(let id, _, _, _, _) = task { return plan.coachAddedLessonIDs.contains(id) }
        return false
    }
```

5. Replace `refresh()` with:

```swift
    private func refresh() {
        let coordinator = TodayPlanCoordinator(
            context: context, userID: UserIdentity.current, accessProvider: appState.accessProvider,
            isPremium: appState.premiumProvider.isPremium
        )
        do {
            guard let plan = try coordinator.buildPlan() else {
                loadState = .noContent
                return
            }
            stats = try coordinator.stats()
            coachBriefing = try? coordinator.buildCoachBriefing()
            if let coachBriefing, appState.premiumProvider.isPremium {
                let viewModel = coachViewModel ?? CoachViewModel(cache: appState.coachNoteCache) { [appState] in
                    await appState.loadTutorEngineIfNeeded()
                    return appState.tutorEngine
                }
                viewModel.show(coachBriefing, day: Calendar.current.startOfDay(for: Date()))
                coachViewModel = viewModel
            }
            loadState = .ready(plan)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
```

(`try?` on the briefing: a coach failure must never hide the plan.)

- [ ] **Step 6: Profile — coach section and settings entry**

In `ProfileView`:

1. State: `@State private var coachBriefing: CoachBriefing?` and `@State private var showStudySettings = false`.
2. In the `HEDEFİM` section, after the exam-date row block, add:

```swift
                    Button("Düzenle") { showStudySettings = true }
                        .buttonStyle(.plain).foregroundStyle(Theme.primary)
```

3. After the `HEDEFİM` section, add:

```swift
                if appState.premiumProvider.isPremium, let coachBriefing {
                    section("KOÇ") {
                        row("Bu hafta", "\(coachBriefing.weekDaysStudied) gün · \(coachBriefing.weekMinutes) dk")
                        Divider()
                        row("Biten ders (7 gün)", "\(coachBriefing.weekLessonsCompleted)")
                        if let skill = coachBriefing.plan.weakestSkill {
                            Divider()
                            row("En çok ihtiyaç", skill.displayName, tint: Theme.accent)
                        }
                        if let finish = coachBriefing.plan.targetFinishDay, coachBriefing.plan.status != .scopeComplete {
                            Divider()
                            row("Hedef bitiş", finish.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "tr_TR"))), tint: Theme.primary)
                        }
                    }
                }
```

4. Add `.sheet(isPresented: $showStudySettings) { StudySettingsSheet() }` next to the other sheets.
5. In `refresh()`, after `stats = ...`:

```swift
        coachBriefing = try? TodayPlanCoordinator(context: context, userID: userID, accessProvider: appState.accessProvider).buildCoachBriefing()
```

- [ ] **Step 7: Paywall line**

In `PaywallView.benefits`, `.premium` case, replace `"Çalışma koçu (yakında)",` with:

```swift
                "Çalışma koçu: sınav tarihine göre kişisel program",
```

- [ ] **Step 8: TestFlight checklist**

In `docs/store-setup.md`, append to the list in section 3 (after the last Slice 7d item):

```markdown
- [ ] Slice 9 AI Koç (premium, sandbox abonelikle): Bugün'ün üstünde koç kartı görünüyor mu (durum rozeti, ilerleme satırı)? Sınav tarihi yokken "Sınav tarihini ekle" daveti ve Çalışma ayarları sayfası çalışıyor mu? Sınav tarihini çok yakın (7 günden az) yapınca plan yalnızca tekrar mı oluyor? Tarihi yetişilemeyecek kadar yakın yapınca "Tempo yetmiyor" ve iki buton çıkıyor mu?
- [ ] AI Koç kişisel not: "Koçtan kişisel not al" → model yüklenip Türkçe, 2-4 cümlelik, sayıları doğru bir not yazıyor mu? Uygulamayı açınca model KENDİLİĞİNDEN yüklenmiyor mu (bellek)? Ücretsiz kullanıcıda kilitli "AI Koç" kartı paywall'u açıyor mu? Büyük yazı boyutunda kart taşmıyor mu?
```

- [ ] **Step 9: Commit, push, verify CI**

```bash
git add App/Sources/EnglishApp/Coach/CoachCardView.swift App/Sources/EnglishApp/Profile/StudySettingsSheet.swift App/Sources/EnglishApp/Today/TodayPlanView.swift App/Sources/EnglishApp/DesignSystem/PlanTaskRow.swift App/Sources/EnglishApp/Profile/ProfileView.swift App/Sources/EnglishApp/Store/PaywallView.swift App/Tests/EnglishAppTests/StudySettingsTests.swift docs/store-setup.md
git commit -F - <<'EOF'
Show the AI coach on Today and Profile with a study settings sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git push origin learning-engine
```

Expected: `App Build` green (compiles every view; `StudySettingsTests` passes); `Swift Tests` green.

---

## Self-review

**1. Spec coverage.**

| Spec requirement | Task |
|---|---|
| CoachPlanner rules, statuses, precedence, free pace, window, directive, weakest skill | 1 |
| DailyPlanBuilder optional directive, review-only, catch-up, `coachAddedLessonIDs`, nil = unchanged | 2 |
| CoachRequest/prompt/validator, protocol method, MLX implementation | 3 |
| Templates per status + exam-date invite, 30 s timeout, template fallback, same-day cache keyed by template | 4 |
| Premium-only directive, briefing (last 7 days, streak) | 5 |
| Coach card, badge, progress line, locked line, unreachable buttons, invite, "Koç ekledi", teaser → paywall, Profile KOÇ section, settings sheet, paywall line, model only on button | 6 |
| No schema change | all (no `@Model` edits) |
| TestFlight device checks | 6 step 8 |

**2. Placeholder scan.** The only elided code is Task 5 step 2's "existing ... unchanged" block inside `buildPlanInput()`, which names every existing statement that stays; everything new is written out.

**3. Type consistency.** `CoachDirective(extraLessonMinutes:reviewOnly:)`, `CoachPlan(status:mode:daysToExam:targetFinishDay:daysToTargetFinish:remainingMinutes:completedShare:lockedLessonCount:requiredMinutesPerDay:weakestSkill:directive:)`, `CoachBriefing(plan:weekDaysStudied:weekMinutes:weekLessonsCompleted:streak:)`, `CoachRequest(facts:draft:)`, `CoachViewModel(cache:timeoutSeconds:engineProvider:)`, `withTutorTimeout(nanoseconds:_:)`, `TodayPlanCoordinator(..., isPremium:)` are used identically in every task.

**4. Review Focus.** Each of the five lines names its pinning test and owning task.
