import XCTest
@testable import TutorEngine

final class PromptBuilderTests: XCTestCase {
    private func makeRequest(ask: TutorAsk) -> TutorRequest {
        TutorRequest(
            headword: "economy",
            definition: "the system of production, trade, and management of money in a country or region",
            exampleSentences: ["The country's economy grew by three percent last year."],
            translationTR: "ekonomi",
            ask: ask
        )
    }

    func test_build_includesCardContextForEveryAsk() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.simplerExplanation)))

        XCTAssertTrue(prompt.contains("economy"))
        XCTAssertTrue(prompt.contains("the system of production, trade, and management of money in a country or region"))
        XCTAssertTrue(prompt.contains("The country's economy grew by three percent last year."))
        XCTAssertTrue(prompt.contains("ekonomi"))
    }

    func test_build_simplerExplanation_asksForSimplerWording() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.simplerExplanation)))
        XCTAssertTrue(prompt.contains("simpler"))
    }

    func test_build_anotherExample_asksForNewExampleSentence() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.anotherExample)))
        XCTAssertTrue(prompt.contains("new") && prompt.contains("example sentence"))
    }

    func test_build_compareToSimilarWords_asksForComparison() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .quickAction(.compareToSimilarWords)))
        XCTAssertTrue(prompt.contains("differs") || prompt.contains("different"))
    }

    func test_build_freeText_includesTheLearnersExactQuestion() {
        let prompt = PromptBuilder.build(for: makeRequest(ask: .freeText("Can I use this in a sentence about my own salary?")))
        XCTAssertTrue(prompt.contains("Can I use this in a sentence about my own salary?"))
    }

    func test_build_english_usesEnglishLearnerOpening_omitsTranslation_andAsksForEnglish() {
        let request = TutorRequest(
            headword: "economy",
            definition: "the system of production, trade, and management of money in a country or region",
            exampleSentences: ["The country's economy grew by three percent last year."],
            translationTR: "ekonomi",
            ask: .quickAction(.simplerExplanation),
            learnerLanguage: .english
        )
        let prompt = PromptBuilder.build(for: request)

        XCTAssertTrue(prompt.contains("You are a concise, encouraging English tutor helping an English learner."))
        XCTAssertTrue(prompt.hasSuffix("Answer in English."))
        XCTAssertFalse(prompt.contains("Turkish"))
        XCTAssertFalse(prompt.contains("YDS"))
        XCTAssertFalse(prompt.contains("ekonomi"))
    }
}
