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

    private func makeViewModel(engine: FakeCoachEngine?, cache: CoachNoteCache = CoachNoteCache(), timeoutSeconds: UInt64 = 30) -> CoachViewModel {
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
