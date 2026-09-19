import XCTest
@testable import TutorEngine

final class QuestionPromptBuilderTests: XCTestCase {
    let request = QuestionTutorRequest(
        prompt: "By the time the central bank announced the new interest rate, most investors ---- their portfolios.",
        options: [
            "have already restructured",
            "had already restructured",
            "already restructure",
            "are already restructuring",
            "will already restructure"
        ],
        correctIndex: 1,
        selectedIndex: 0,
        explanationTR: "«By the time» kalıbı past perfect ister.",
        ask: .quickAction(.simplerExplanation)
    )

    func test_promptCarriesTheQuestionOptionsKeyAndTheLearnersAnswer() {
        let prompt = QuestionPromptBuilder.build(for: request)
        XCTAssertTrue(prompt.contains("By the time the central bank announced"))
        XCTAssertTrue(prompt.contains("A) have already restructured"))
        XCTAssertTrue(prompt.contains("E) will already restructure"))
        XCTAssertTrue(prompt.contains("Correct answer: B) had already restructured"))
        XCTAssertTrue(prompt.contains("The learner chose: A) have already restructured"))
    }

    func test_anUnansweredQuestion_saysSo() {
        let unanswered = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
            selectedIndex: nil, explanationTR: request.explanationTR, ask: request.ask
        )
        let prompt = QuestionPromptBuilder.build(for: unanswered)
        XCTAssertTrue(prompt.contains("The learner has not answered yet."))
        XCTAssertFalse(prompt.contains("The learner chose:"))
    }

    func test_quickActions_produceDistinctInstructions() {
        func instruction(_ action: QuickAction) -> String {
            QuestionPromptBuilder.build(for: QuestionTutorRequest(
                prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
                selectedIndex: request.selectedIndex, explanationTR: request.explanationTR,
                ask: .quickAction(action)
            ))
        }
        XCTAssertTrue(instruction(.simplerExplanation).contains("Explain, in plain English"))
        XCTAssertTrue(instruction(.anotherExample).contains("Write one new example sentence"))
        XCTAssertTrue(instruction(.compareToSimilarWords).contains("why the option the learner chose is wrong"))
        XCTAssertNotEqual(instruction(.simplerExplanation), instruction(.anotherExample))
    }

    func test_freeTextQuestion_isQuotedIntoThePrompt() {
        let asked = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: request.correctIndex,
            selectedIndex: request.selectedIndex, explanationTR: request.explanationTR,
            ask: .freeText("Why not present perfect?")
        )
        XCTAssertTrue(QuestionPromptBuilder.build(for: asked).contains("The learner asks: \"Why not present perfect?\""))
    }

    func test_promptIsDeterministic() {
        XCTAssertEqual(QuestionPromptBuilder.build(for: request), QuestionPromptBuilder.build(for: request))
    }
}
