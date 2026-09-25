import XCTest
@testable import TutorEngine

final class GoalPromptTests: XCTestCase {
    func card(translation: String = "ekonomi", language: LearnerLanguage = .turkish, goal: String? = nil) -> TutorRequest {
        TutorRequest(
            headword: "economy", definition: "d", exampleSentences: ["a", "b"], translationTR: translation,
            ask: .quickAction(.simplerExplanation), learnerLanguage: language, goalDescription: goal
        )
    }

    func question(language: LearnerLanguage = .turkish, goal: String? = nil) -> QuestionTutorRequest {
        QuestionTutorRequest(
            prompt: "Q", options: ["x", "y"], correctIndex: 0, selectedIndex: 1, explanationTR: "E",
            ask: .quickAction(.simplerExplanation), learnerLanguage: language, goalDescription: goal
        )
    }

    func test_ydsTurkishCardPrompt_isUnchanged() {
        XCTAssertEqual(
            PromptBuilder.build(for: card()),
            "You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam.\n"
                + "The learner is currently studying this word:\n\n"
                + "Word: economy\nDefinition: d\nExample sentences: a / b\nTurkish translation: ekonomi\n\n"
                + "Explain the word \"economy\" in simpler, plainer English than the definition above. Keep it to 2-3 short sentences."
        )
    }

    func test_emptyTranslation_omitsTheTranslationLine() {
        let prompt = PromptBuilder.build(for: card(translation: "", goal: "improving their business English"))
        XCTAssertFalse(prompt.contains("Turkish translation"))
        XCTAssertTrue(prompt.contains("Example sentences: a / b\n\nExplain the word"))
    }

    func test_goalDescription_replacesTheYDSOpening_inBothLanguages() {
        let turkish = PromptBuilder.build(for: card(goal: "improving their business English"))
        XCTAssertTrue(turkish.hasPrefix("You are a concise, encouraging English tutor helping a Turkish-speaking learner who is improving their business English.\n"))
        XCTAssertFalse(turkish.contains("YDS"))

        let english = PromptBuilder.build(for: card(language: .english, goal: "improving their everyday English"))
        XCTAssertTrue(english.hasPrefix("You are a concise, encouraging English tutor helping an English learner who is improving their everyday English.\n"))
        XCTAssertTrue(english.hasSuffix("Answer in English."))
    }

    func test_questionPrompt_ydsKeepsTurkishExplanationNote_otherGoalsDoNot() {
        let yds = QuestionPromptBuilder.build(for: question())
        XCTAssertTrue(yds.hasPrefix("You are a concise, encouraging English tutor helping a Turkish-speaking learner preparing for the YDS exam."))
        XCTAssertTrue(yds.contains("(in Turkish): E"))

        let business = QuestionPromptBuilder.build(for: question(goal: "improving their business English"))
        XCTAssertTrue(business.hasPrefix("You are a concise, encouraging English tutor helping a Turkish-speaking learner who is improving their business English."))
        XCTAssertTrue(business.contains("(it may be in another language): E"))
        XCTAssertFalse(business.contains("YDS"))
    }
}
