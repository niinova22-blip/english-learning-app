import XCTest
@testable import EnglishApp

final class ReminderRulesTests: XCTestCase {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func test_daily_nextSevenEvenings_includingToday_whenNotDoneYet() {
        let dates = ReminderRules.dailyFireDates(now: date(2026, 9, 25, 10), hour: 20, minute: 0, todayComplete: false, calendar: calendar)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, date(2026, 9, 25, 20))
        XCTAssertEqual(dates.last, date(2026, 10, 1, 20))
    }

    func test_daily_skipsToday_whenThePlanIsDone() {
        let dates = ReminderRules.dailyFireDates(now: date(2026, 9, 25, 10), hour: 20, minute: 0, todayComplete: true, calendar: calendar)
        XCTAssertEqual(dates.first, date(2026, 9, 26, 20))
        XCTAssertEqual(dates.count, 7)
    }

    func test_daily_skipsToday_whenTheTimeHasPassed() {
        let dates = ReminderRules.dailyFireDates(now: date(2026, 9, 25, 21), hour: 20, minute: 30, todayComplete: false, calendar: calendar)
        XCTAssertEqual(dates.first, date(2026, 9, 26, 20, 30))
    }

    func test_daily_keepsWallClockTimeAcrossADSTChange() {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let now = berlin.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9))!
        let dates = ReminderRules.dailyFireDates(now: now, hour: 20, minute: 0, todayComplete: false, calendar: berlin)
        XCTAssertTrue(dates.allSatisfy { berlin.component(.hour, from: $0) == 20 }, "DST ends on 25 Oct in Berlin")
    }

    func test_trialReminder_isOneDayBeforeTheCharge_onlyWhileStillAhead() {
        let end = date(2026, 10, 2, 9)
        XCTAssertEqual(ReminderRules.trialReminderDate(trialEndsAt: end, now: date(2026, 9, 25, 9)), date(2026, 10, 1, 9))
        XCTAssertNil(ReminderRules.trialReminderDate(trialEndsAt: end, now: date(2026, 10, 1, 12)), "less than a day left")
        XCTAssertNil(ReminderRules.trialReminderDate(trialEndsAt: nil, now: date(2026, 9, 25, 9)))
    }
}

final class FakeNotificationClient: NotificationCenterClient, @unchecked Sendable {
    var authorized = true
    var requestResult = true
    private(set) var requestCount = 0
    private(set) var scheduled: [String: Date] = [:]
    var foreign: [String] = []

    func isAuthorized() async -> Bool { authorized }
    func isUndetermined() async -> Bool { !authorized && requestCount == 0 }
    func requestAuthorization() async -> Bool {
        requestCount += 1
        authorized = requestResult
        return requestResult
    }
    func pendingIdentifiers() async -> [String] { Array(scheduled.keys) + foreign }
    func remove(identifiers: [String]) { identifiers.forEach { scheduled[$0] = nil } }
    func add(identifier: String, title: String, body: String, at date: Date) async throws { scheduled[identifier] = date }
}

@MainActor
final class ReminderSchedulerTests: XCTestCase {
    func makeSettings(enabled: Bool) -> ReminderSettings {
        let settings = ReminderSettings(defaults: UserDefaults(suiteName: "reminders-\(UUID().uuidString)")!)
        settings.isEnabled = enabled
        return settings
    }

    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func test_enabledReminder_schedulesSevenDays_andLeavesOtherNotificationsAlone() async {
        let client = FakeNotificationClient()
        client.foreign = ["someone-else"]
        let scheduler = ReminderScheduler(client: client, settings: makeSettings(enabled: true), now: { self.now })
        await scheduler.reschedule(todayComplete: false, trialEndsAt: nil)
        XCTAssertEqual(client.scheduled.keys.filter { $0.hasPrefix("lexpath.daily.") }.count, 7)
        XCTAssertEqual(client.foreign, ["someone-else"])
    }

    func test_disabledReminder_removesPreviouslyScheduledDailyReminders() async {
        let client = FakeNotificationClient()
        let settings = makeSettings(enabled: true)
        let scheduler = ReminderScheduler(client: client, settings: settings, now: { self.now })
        await scheduler.reschedule(todayComplete: false, trialEndsAt: nil)
        settings.isEnabled = false
        await scheduler.reschedule(todayComplete: false, trialEndsAt: nil)
        XCTAssertTrue(client.scheduled.isEmpty)
    }

    func test_trialEnd_schedulesOneReminder_andAsksPermissionOnlyThen() async {
        let client = FakeNotificationClient()
        client.authorized = false
        let scheduler = ReminderScheduler(client: client, settings: makeSettings(enabled: false), now: { self.now })
        await scheduler.reschedule(todayComplete: false, trialEndsAt: nil)
        XCTAssertEqual(client.requestCount, 0, "no trial, reminders off: never prompt")

        let end = now.addingTimeInterval(7 * 86_400)
        await scheduler.reschedule(todayComplete: false, trialEndsAt: end)
        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.scheduled["lexpath.trial-end"], end.addingTimeInterval(-86_400))

        await scheduler.reschedule(todayComplete: false, trialEndsAt: nil)
        XCTAssertNil(client.scheduled["lexpath.trial-end"], "trial over or cancelled")
    }

    func test_enable_asksPermission_andTurnsOffWhenDenied() async {
        let client = FakeNotificationClient()
        client.authorized = false
        client.requestResult = false
        let settings = makeSettings(enabled: false)
        let scheduler = ReminderScheduler(client: client, settings: settings, now: { self.now })
        let granted = await scheduler.enableDailyReminder()
        XCTAssertFalse(granted)
        XCTAssertFalse(settings.isEnabled)
    }
}
