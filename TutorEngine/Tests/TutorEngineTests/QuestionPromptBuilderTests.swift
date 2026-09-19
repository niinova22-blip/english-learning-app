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

    func test_compareAction_whenLearnerWasCorrect_asksAboutTheOtherOptions() {
        let correct = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: 1,
            selectedIndex: 1, explanationTR: request.explanationTR,
            ask: .quickAction(.compareToSimilarWords)
        )
        let prompt = QuestionPromptBuilder.build(for: correct)
        XCTAssertTrue(prompt.contains("The learner answered correctly."))
        XCTAssertTrue(prompt.contains("why each of the other options is wrong or less suitable"))
        XCTAssertFalse(prompt.contains("why the option the learner chose is wrong"))
    }

    func test_passage_isIncludedBeforeTheQuestionOnlyWhenPresent() {
        let withPassage = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: 1,
            selectedIndex: 0, explanationTR: request.explanationTR,
            ask: request.ask, passage: "Central banks shape markets."
        )
        let prompt = QuestionPromptBuilder.build(for: withPassage)
        XCTAssertTrue(prompt.contains("Passage:\n---\nCentral banks shape markets.\n---\n\nQuestion:"))
        XCTAssertFalse(QuestionPromptBuilder.build(for: request).contains("Passage:"))
    }

    func test_outOfRangeIndices_fallBackToDash() {
        let odd = QuestionTutorRequest(
            prompt: request.prompt, options: request.options, correctIndex: 9,
            selectedIndex: 7, explanationTR: request.explanationTR, ask: request.ask
        )
        let prompt = QuestionPromptBuilder.build(for: odd)
        XCTAssertTrue(prompt.contains("Correct answer: -\n"))
        XCTAssertTrue(prompt.contains("The learner chose: -\n"))
    }

    func test_promptIsDeterministic() {
        XCTAssertEqual(QuestionPromptBuilder.build(for: request), QuestionPromptBuilder.build(for: request))
    }
}
