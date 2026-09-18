import XCTest
@testable import LearningEngine

final class StreakCalculatorTests: XCTestCase {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func test_noActivity_isZero() {
        XCTAssertEqual(StreakCalculator.streak(activityDates: [], now: date(2026, 9, 14), calendar: calendar), 0)
    }

    func test_consecutiveDaysEndingToday_countsAll_andMultipleEventsPerDayCountOnce() {
        let dates = [date(2026, 9, 12), date(2026, 9, 13, 8), date(2026, 9, 13, 22), date(2026, 9, 14, 9)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14, 23), calendar: calendar), 3)
    }

    func test_todayWithoutActivity_doesNotBreakStreakFromYesterday() {
        let dates = [date(2026, 9, 12), date(2026, 9, 13)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14, 7), calendar: calendar), 2)
    }

    func test_gapBeforeYesterday_resetsToZero() {
        XCTAssertEqual(StreakCalculator.streak(activityDates: [date(2026, 9, 11)], now: date(2026, 9, 14), calendar: calendar), 0)
    }

    func test_gapInsideHistory_countsOnlyRecentRun() {
        let dates = [date(2026, 9, 10), date(2026, 9, 12), date(2026, 9, 13), date(2026, 9, 14)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 14), calendar: calendar), 3)
    }

    func test_monthBoundary() {
        let dates = [date(2026, 8, 31), date(2026, 9, 1)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 9, 1), calendar: calendar), 2)
    }

    func test_dstSpringForward_isStillConsecutive() {
        // US DST starts 2026-03-08 (a 23-hour day).
        let dates = [date(2026, 3, 7, 23), date(2026, 3, 8, 1), date(2026, 3, 9, 0)]
        XCTAssertEqual(StreakCalculator.streak(activityDates: dates, now: date(2026, 3, 9, 10), calendar: calendar), 3)
    }
}
