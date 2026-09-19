// App/Tests/EnglishAppTests/PracticeSessionViewModelTests.swift
import XCTest
import SwiftData
@testable import EnglishApp
import LearningEngine

@MainActor
final class PracticeSessionViewModelTests: XCTestCase {
    let userID = "u"
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: AppModelContainer.schema, configurations: [ModelConfiguration(schema: AppModelContainer.schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        AppModelContainer.seedRealContentIfNeeded(in: context)
        return context
    }

    func viewModel(_ context: ModelContext, mode: PracticeSessionViewModel.Mode) -> PracticeSessionViewModel {
        PracticeSessionViewModel(mode: mode, context: context, userID: userID, clock: { self.now }, seed: 7)
    }

    /// Answers every served question, choosing the key for the first
    /// `correctCount` of them and a deliberately wrong option for the rest.
    func answerAll(_ vm: PracticeSessionViewModel, correctCount: Int) {
        for index in vm.questions.indices {
            guard let question = vm.current else { return XCTFail("ran out of questions at \(index)") }
            let wrong = question.correctIndex == 0 ? 1 : 0
            vm.select(index < correctCount ? question.correctIndex : wrong)
            vm.next()
        }
    }

    func test_grammarLesson_startsOnTheTurkishExplanation_thenGoesToQuestions() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-tenses"))
        try vm.start()

        guard case .explanation(let text) = vm.step else { return XCTFail("expected .explanation, got \(vm.step)") }
        XCTAssertTrue(text.contains("Past perfect"))
        XCTAssertEqual(vm.lessonTitle, "Zamanlar (Tenses)")
        XCTAssertEqual(vm.skill, .grammar)

        vm.beginQuestions()
        XCTAssertEqual(vm.step, .question)
        XCTAssertEqual(vm.questions.count, 8, "grammar lessons serve up to 8 questions")
        XCTAssertEqual(vm.progressText, "1/8")
        XCTAssertEqual(vm.current?.options.count, 5)
    }

    func test_readingLesson_skipsTheExplanation_andExposesThePassage() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()

        XCTAssertEqual(vm.step, .question)
        XCTAssertEqual(vm.questions.count, 5, "non-grammar lessons serve up to 5 questions")
        XCTAssertEqual(vm.passage?.title, "Carbon Pricing in Practice")
        XCTAssertFalse(vm.passage?.body.isEmpty ?? true)
    }

    func test_selectingAnOption_writesAnAttemptImmediately_andShowsFeedback() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)

        vm.select(question.correctIndex)

        XCTAssertEqual(vm.selectedIndex, question.correctIndex)
        XCTAssertTrue(vm.isAnswered)
        let attempts = try context.fetch(FetchDescriptor<QuestionAttempt>())
        XCTAssertEqual(attempts.count, 1)
        XCTAssertEqual(attempts.first?.questionID, question.id)
        XCTAssertEqual(attempts.first?.selectedIndex, question.correctIndex)
        XCTAssertTrue(attempts.first?.wasCorrect ?? false)
        XCTAssertEqual(attempts.first?.answeredAt, now)
    }

    func test_selectingTwice_isIgnored() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)

        vm.select(question.correctIndex)
        vm.select(question.correctIndex == 0 ? 1 : 0)

        XCTAssertEqual(vm.selectedIndex, question.correctIndex)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 1)
    }

    func test_completingWithEveryAnswerCorrect_ratesEasy_marksTheLessonDone_andSummarises() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        answerAll(vm, correctCount: 5)

        XCTAssertEqual(vm.step, .summary)
        let summary = vm.summary()
        XCTAssertEqual(summary.correctCount, 5)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.percent, 100)
        XCTAssertTrue(summary.missedPrompts.isEmpty)
        XCTAssertNotNil(summary.nextReviewText)

        let logs = try context.fetch(FetchDescriptor<ReviewLog>())
        XCTAssertEqual(logs.map(\.itemID), ["yds-practice-card-reading-1"])
        XCTAssertEqual(logs.first?.rating, .easy)

        let progressID = LessonProgress.makeID(userID: userID, lessonID: "yds-practice-lesson-reading-1")
        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first)
        XCTAssertEqual(progress.completedAt, now)
    }

    func test_scoringUnderFiftyPercent_ratesAgain_andListsTheMissedQuestions() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        answerAll(vm, correctCount: 2)   // 2/5 = 40%

        let summary = vm.summary()
        XCTAssertEqual(summary.correctCount, 2)
        XCTAssertEqual(summary.percent, 40)
        XCTAssertEqual(summary.missedPrompts.count, 3)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLog>()).first?.rating, .again)
    }

    func test_quittingMidway_leavesTheLessonIncomplete_butKeepsTheAttempts() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)
        vm.select(question.correctIndex)
        // The view is dismissed here; no further calls.

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 0)
        let progressID = LessonProgress.makeID(userID: userID, lessonID: "yds-practice-lesson-reading-1")
        let progress = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first)
        XCTAssertNil(progress.completedAt, "a half-finished session must never mark the lesson complete")
    }

    func test_reopeningAfterAQuit_startsFromTheBeginning_butPrefersUnattemptedQuestions() throws {
        let context = try makeContext()
        // Tenses has 8 questions and serves 8, so instead use sentence
        // completion: 15 authored, 5 served — selection actually has a choice.
        let first = viewModel(context, mode: .lesson(id: "yds-practice-lesson-sentence-1"))
        try first.start()
        let firstIDs = first.questions.map(\.id)
        XCTAssertEqual(firstIDs.count, 5)
        answerAll(first, correctCount: 5)

        let second = viewModel(context, mode: .lesson(id: "yds-practice-lesson-sentence-1"))
        try second.start()
        XCTAssertEqual(second.currentIndex, 0)
        XCTAssertEqual(second.progressText, "1/5")
        XCTAssertTrue(
            second.questions.map(\.id).allSatisfy { !firstIDs.contains($0) },
            "never-attempted questions outrank already-answered ones"
        )
    }

    func test_reviewMode_reSelectsFromTheSameLessonsPool() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .review(lessonID: "yds-practice-lesson-sentence-1", itemID: "yds-practice-card-sentence-1"))
        try vm.start()

        XCTAssertEqual(vm.questions.count, 5)
        XCTAssertEqual(vm.lessonTitle, "Cümle Tamamlama")
        XCTAssertEqual(vm.contextLine, "KONU TEKRARI · CÜMLE TAMAMLAMA")
        answerAll(vm, correctCount: 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ReviewLog>()).first?.itemID, "yds-practice-card-sentence-1")
    }

    func test_poolSmallerThanTheSelectionSize_asksEveryQuestion() throws {
        let context = try makeContext()
        // Reading lesson 1 has exactly 5 questions and the target is 5.
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        XCTAssertEqual(vm.questions.count, 5)
    }

    func test_missingLesson_isUnavailable_andWritesNothing() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "no-such-lesson"))
        try vm.start()

        XCTAssertEqual(vm.step, .unavailable)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LessonProgress>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 0)
    }

    func test_saveFailureOnFinish_surfacesAnError_keepsTheLessonIncomplete_andRetrySucceeds() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        // Answer everything; arm the failure only for the final "Sonraki" (the finish).
        for index in vm.questions.indices {
            let question = try XCTUnwrap(vm.current)
            vm.select(question.correctIndex)
            if index == vm.questions.count - 1 { vm.failNextSaveForTesting = true }
            vm.next()
        }

        XCTAssertNotNil(vm.saveError)
        XCTAssertEqual(vm.step, .question, "the screen stays open — no half-complete 'lesson done' state")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 0)
        let progressID = LessonProgress.makeID(userID: userID, lessonID: "yds-practice-lesson-reading-1")
        let before = try XCTUnwrap(context.fetch(FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.id == progressID })).first)
        XCTAssertNil(before.completedAt)

        vm.retrySave()

        XCTAssertNil(vm.saveError)
        XCTAssertEqual(vm.step, .summary)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewLog>()), 1)
        XCTAssertEqual(before.completedAt, now)
    }

    func test_attemptSaveFailure_doesNotRegisterTheAnswer_andRetryRewritesIt() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        let question = try XCTUnwrap(vm.current)
        vm.failNextSaveForTesting = true

        vm.select(question.correctIndex)

        XCTAssertNotNil(vm.saveError)
        XCTAssertNil(vm.selectedIndex)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 0)

        vm.clearSaveError()
        vm.select(question.correctIndex)
        XCTAssertEqual(vm.selectedIndex, question.correctIndex)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<QuestionAttempt>()), 1)
    }

    private func orderedQuestionIDs(_ context: ModelContext, lessonID: String) throws -> [String] {
        let lesson = try XCTUnwrap(context.fetch(FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonID })).first)
        return lesson.questions.sorted { $0.order < $1.order }.map(\.id)
    }

    func test_lastAttemptDecidesCorrectness_wrongThenRightCountsAsCorrect_andRightThenWrongAsWrong() throws {
        let context = try makeContext()
        let lessonID = "yds-practice-lesson-sentence-1"
        let ids = try orderedQuestionIDs(context, lessonID: lessonID)
        XCTAssertEqual(ids.count, 15)
        func attempt(_ id: String, correct: Bool, at seconds: TimeInterval) {
            context.insert(QuestionAttempt(userID: userID, questionID: id, wasCorrect: correct,
                                           answeredAt: Date(timeIntervalSince1970: seconds), selectedIndex: 0))
        }
        // ids[0]: wrong@10 then right@20 -> last is correct (lowest priority).
        attempt(ids[0], correct: false, at: 10); attempt(ids[0], correct: true, at: 20)
        // ids[1]: right@10 then wrong@20 -> last is wrong (must be served).
        attempt(ids[1], correct: true, at: 10); attempt(ids[1], correct: false, at: 20)
        // The other 13: correct@15 (older than ids[0]'s 20).
        for id in ids.dropFirst(2) { attempt(id, correct: true, at: 15) }
        try context.save()

        let vm = viewModel(context, mode: .lesson(id: lessonID))
        try vm.start()
        let served = vm.questions.map(\.id)

        XCTAssertEqual(served.count, 5)
        XCTAssertTrue(served.contains(ids[1]), "last attempt wrong -> wrong tier -> served")
        XCTAssertFalse(served.contains(ids[0]), "last attempt correct and most recent -> served last, cut by the size limit")
    }

    func test_otherUsersAttemptsDoNotAffectSelection() throws {
        let context = try makeContext()
        let lessonID = "yds-practice-lesson-sentence-1"
        let ids = try orderedQuestionIDs(context, lessonID: lessonID)
        // Another user answered the first five correctly, recently.
        for id in ids.prefix(5) {
            context.insert(QuestionAttempt(userID: "someone-else", questionID: id, wasCorrect: true,
                                           answeredAt: Date(timeIntervalSince1970: 1_700_000_000), selectedIndex: 0))
        }
        try context.save()

        let vm = viewModel(context, mode: .lesson(id: lessonID))
        try vm.start()

        XCTAssertEqual(vm.questions.map(\.id), Array(ids.prefix(5)), "this user has no history: authored order")
    }

    func test_contextLine_usesTurkishUppercasing_withADottedCapitalI() throws {
        let context = try makeContext()
        let vm = viewModel(context, mode: .lesson(id: "yds-practice-lesson-reading-1"))
        try vm.start()
        // tr_TR uppercases "i" to the dotted "İ": "Karbon Fiyatlandırması" has
        // none, but the "Okuma:" prefix and the word "İngilizce" elsewhere do.
        XCTAssertEqual(vm.contextLine, "YENİ DERS · OKUMA: KARBON FİYATLANDIRMASI")
    }
}
