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

    func test_suggestedExamDate_keepsAFutureStoredDate_elseFallsBackToTodayPlusThirtyDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 10))!
        let startOfToday = calendar.startOfDay(for: now)
        let todayPlusThirty = calendar.date(byAdding: .day, value: 30, to: startOfToday)!

        let futureDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        XCTAssertEqual(StudySettings.suggestedExamDate(stored: futureDate, now: now, calendar: calendar), futureDate)

        XCTAssertEqual(StudySettings.suggestedExamDate(stored: startOfToday, now: now, calendar: calendar), todayPlusThirty)

        XCTAssertEqual(StudySettings.suggestedExamDate(stored: nil, now: now, calendar: calendar), todayPlusThirty)

        let pastDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        XCTAssertEqual(StudySettings.suggestedExamDate(stored: pastDate, now: now, calendar: calendar), todayPlusThirty)
    }
}
