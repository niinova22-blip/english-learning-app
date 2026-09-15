import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

@MainActor
final class StudySessionViewModelTests: XCTestCase {
    let userID = "u"
    var clockNow = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        _ = try ContentSeeder.seed(bundledData: TestPackageJSON.make(), into: context)
        return context
    }

    func makeVM(_ mode: StudySessionViewModel.Mode, _ context: ModelContext) -> StudySessionViewModel {
        StudySessionViewModel(mode: mode, context: context, userID: userID, clock: { [unowned self] in self.clockNow })
    }

    func progressRow(_ context: ModelContext, _ lessonID: String) throws -> LessonProgress? {
        let id = LessonProgress.makeID(userID: userID, lessonID: lessonID)
        return try context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == id })).first
    }

    func test_lessonStart_loadsItemsInOrder_andCreatesProgress() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()

        XCTAssertEqual(vm.cards.map(\.id), ["item-u0-l0-i0", "item-u0-l0-i1"])
        XCTAssertEqual(vm.progressText, "1/2")
        XCTAssertEqual(vm.contextLine, "YENİ DERS · UNIT 0 · 1")
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0"))
        XCTAssertNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_ratingEveryCard_finishesAndCompletesLesson_withSummary() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()

        vm.reveal()
        XCTAssertTrue(vm.isRevealed)
        vm.rate(.good)
        XCTAssertFalse(vm.isRevealed)
        XCTAssertEqual(vm.progressText, "2/2")
        vm.reveal()
        vm.rate(.again)

        XCTAssertTrue(vm.isFinished)
        XCTAssertEqual(try progressRow(context, "lesson-u0-l0")?.completedAt, clockNow)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 2)
        XCTAssertEqual(vm.summary(), .init(title: "Ders tamamlandı", subtitle: "Unit 0 · 1", cardCount: 2, knownShare: 0.5, needsReview: ["word001"]))
    }

    func test_reenteringALesson_resumesAtFirstUnratedItem() throws {
        let context = try makeContext()
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i0", rating: .good, now: clockNow, in: context, scheduler: FSRSScheduler())

        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        XCTAssertEqual(vm.cards.map(\.id), ["item-u0-l0-i1"])
        vm.rate(.good)
        XCTAssertTrue(vm.isFinished)
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_leavingEarly_keepsRatings_andLessonStaysIncomplete() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        vm.rate(.good)

        XCTAssertFalse(vm.isFinished)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserItemState>()), 1)
        XCTAssertNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_lessonWithNothingLeft_finishesImmediately() throws {
        let context = try makeContext()
        for i in 0..<2 {
            try FSRSStateStore().recordReview(userID: userID, itemID: "item-u0-l0-i\(i)", rating: .good, now: clockNow, in: context, scheduler: FSRSScheduler())
        }
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        XCTAssertTrue(vm.isFinished)
        XCTAssertNotNil(try progressRow(context, "lesson-u0-l0")?.completedAt)
    }

    func test_reviewMode_loadsOnlyDueSeenItems() throws {
        let context = try makeContext()
        let threeDaysAgo = clockNow.addingTimeInterval(-3 * 86_400)
        try FSRSStateStore().recordReview(userID: userID, itemID: "item-u1-l0-i0", rating: .again, now: threeDaysAgo, in: context, scheduler: FSRSScheduler())

        let vm = makeVM(.review(cardCount: 10), context)
        try vm.start()
        XCTAssertEqual(vm.cards.map(\.id), ["item-u1-l0-i0"])
        XCTAssertEqual(vm.contextLine, "TEKRAR")
        vm.rate(.good)
        XCTAssertEqual(vm.summary().title, "Tekrar tamamlandı")
        XCTAssertNil(vm.summary().subtitle)
    }

    func test_intervalTexts_coverAllRatings_andNewCardAgainIsOneDay() throws {
        let context = try makeContext()
        let vm = makeVM(.lesson(id: "lesson-u0-l0"), context)
        try vm.start()
        let texts = vm.intervalTexts()
        XCTAssertEqual(Set(texts.keys), Set([FSRSRating.again, .hard, .good, .easy]))
        XCTAssertEqual(texts[.again], "1 gün")
    }

    func test_intervalFormatter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14, hour: 22))!
        func plus(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: now)! }
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: now, calendar: calendar), "1 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(1), calendar: calendar), "1 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(25), calendar: calendar), "25 gün")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(60), calendar: calendar), "2 ay")
        XCTAssertEqual(RatingIntervalFormatter.text(from: now, to: plus(400), calendar: calendar), "1 yıl")
    }
}
