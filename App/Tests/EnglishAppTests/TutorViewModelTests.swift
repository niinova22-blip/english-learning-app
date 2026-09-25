import XCTest
import TutorEngine
@testable import EnglishApp
import LearningEngine

private final class FakeTutorEngine: TutorEngine {
    var stubbedResponse = "stub response"
    var stubbedError: Error?
    private(set) var lastRequest: TutorRequest?

    func respond(to request: TutorRequest) async throws -> String {
        lastRequest = request
        if let stubbedError { throw stubbedError }
        return stubbedResponse
    }

    func respond(to chat: ChatRequest) async throws -> String {
        fatalError("not used by TutorViewModelTests")
    }

    private(set) var lastQuestionRequest: QuestionTutorRequest?

    func respond(to question: QuestionTutorRequest) async throws -> String {
        lastQuestionRequest = question
        if let stubbedError { throw stubbedError }
        return stubbedResponse
    }

    func respond(to coach: CoachRequest) async throws -> String {
        fatalError("not used by TutorViewModelTests")
    }
}

private struct StubError: Error {}

@MainActor
final class TutorViewModelTests: XCTestCase {
    private let context = TutorViewModel.TutorContext(
        headword: "economy",
        definition: "the system of production, trade, and management of money in a country or region",
        exampleSentences: ["The country's economy grew by three percent last year."],
        translationTR: "ekonomi"
    )

    func test_questionContext_sendsAQuestionRequestCarryingTheLearnersAnswer() async {
        let engine = FakeTutorEngine()
        engine.stubbedResponse = "Past perfect is needed here."
        let viewModel = TutorViewModel(engine: engine, context: .question(
            prompt: "By the time the bank announced the rate, investors ---- their portfolios.",
            options: ["a", "b", "c", "d", "e"], correctIndex: 1, selectedIndex: 3,
            explanationTR: "«By the time» past perfect ister."
        ))

        await viewModel.ask(.compareToSimilarWords)

        XCTAssertEqual(viewModel.state, .response("Past perfect is needed here."))
        XCTAssertEqual(engine.lastQuestionRequest?.correctIndex, 1)
        XCTAssertEqual(engine.lastQuestionRequest?.selectedIndex, 3)
        XCTAssertEqual(engine.lastQuestionRequest?.ask, .quickAction(.compareToSimilarWords))
        XCTAssertNil(engine.lastRequest, "a question context must not send a card TutorRequest")
    }

    func test_initialState_isIdle() {
        let viewModel = TutorViewModel(engine: FakeTutorEngine(), context: context)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_askQuickAction_onSuccess_setsResponseState() async {
        let engine = FakeTutorEngine()
        engine.stubbedResponse = "Here's a simpler explanation."
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(.simplerExplanation)

        XCTAssertEqual(viewModel.state, .response("Here's a simpler explanation."))
        XCTAssertEqual(engine.lastRequest?.ask, .quickAction(.simplerExplanation))
        XCTAssertEqual(engine.lastRequest?.headword, "economy")
    }

    func test_askQuickAction_onFailure_setsFailureState() async {
        let engine = FakeTutorEngine()
        engine.stubbedError = StubError()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(.anotherExample)

        guard case .failure = viewModel.state else {
            return XCTFail("expected .failure state, got \(viewModel.state)")
        }
    }

    func test_askFreeText_trimsAndSendsTheQuestion() async {
        let engine = FakeTutorEngine()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(freeText: "  Can you use it in a sentence about salary?  ")

        XCTAssertEqual(engine.lastRequest?.ask, .freeText("Can you use it in a sentence about salary?"))
    }

    func test_askFreeText_ignoresBlankQuestion() async {
        let engine = FakeTutorEngine()
        let viewModel = TutorViewModel(engine: engine, context: context)

        await viewModel.ask(freeText: "   ")

        XCTAssertNil(engine.lastRequest)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func test_requests_carryLanguageAndGoal() async {
        let engine = FakeTutorEngine()
        let card = TutorViewModel(engine: engine, context: context, learnerLanguage: .english, goalDescription: "improving their business English")
        await card.ask(.anotherExample)
        XCTAssertEqual(engine.lastRequest?.learnerLanguage, .english)
        XCTAssertEqual(engine.lastRequest?.goalDescription, "improving their business English")

        let question = TutorViewModel(
            engine: engine,
            context: .question(prompt: "Q", options: ["a", "b"], correctIndex: 0, selectedIndex: 1, explanationTR: "E"),
            learnerLanguage: .turkish, goalDescription: nil
        )
        await question.ask(.simplerExplanation)
        XCTAssertEqual(engine.lastQuestionRequest?.learnerLanguage, .turkish)
        XCTAssertNil(engine.lastQuestionRequest?.goalDescription)
    }

    func test_tutorGoal_describesNonYDSGoalsOnly() {
        XCTAssertNil(TutorGoal.description(for: .yds))
        XCTAssertNil(TutorGoal.description(for: nil))
        XCTAssertEqual(TutorGoal.description(for: .business), "improving their business English")
        XCTAssertEqual(TutorGoal.description(for: .conversational), "improving their everyday English")
    }
}
