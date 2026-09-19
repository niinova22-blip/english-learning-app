import XCTest
import TutorEngine
@testable import EnglishApp

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
}
