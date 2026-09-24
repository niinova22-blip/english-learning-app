import XCTest
@testable import TutorEngine

final class CoachPromptBuilderTests: XCTestCase {
    func test_build_isSystemThenUser_withFactsAsBulletsAndTheDraft() {
        let request = CoachRequest(facts: ["Sınava kalan gün: 40", "Seri: 3 gün"], draft: "Sınavına 40 gün var.")
        let messages = CoachPromptBuilder.build(for: request)
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], ChatPromptMessage(role: .system, text: CoachPromptBuilder.systemInstructions))
        XCTAssertEqual(messages[1], ChatPromptMessage(role: .user, text: """
        Öğrencinin durumu:
        - Sınava kalan gün: 40
        - Seri: 3 gün

        Taslak not:
        Sınavına 40 gün var.

        Bu taslağı aynı bilgileri koruyarak, daha kişisel ve cesaret verici bir dille yeniden yaz.
        """))
    }

    func test_systemInstructions_forbidNewNumbers_andAskForTurkish() {
        XCTAssertTrue(CoachPromptBuilder.systemInstructions.contains("Türkçe"))
        XCTAssertTrue(CoachPromptBuilder.systemInstructions.contains("yeni sayı"))
    }

    func test_build_english_isSystemThenUser_withFactsAsBulletsAndTheDraft() {
        let request = CoachRequest(
            facts: ["Days left until the exam: 40", "Streak: 3 days"],
            draft: "You have 40 days left.",
            learnerLanguage: .english
        )
        let messages = CoachPromptBuilder.build(for: request)

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0], ChatPromptMessage(
            role: .system,
            text: "You are a warm, brief study coach for an English learner. Always write in English and address the learner as \"you\". Use only the information you are given; never invent numbers, dates or percentages. Write 2-4 short sentences; no lists or headings."
        ))
        XCTAssertEqual(messages[1], ChatPromptMessage(role: .user, text: """
        The learner's situation:
        - Days left until the exam: 40
        - Streak: 3 days

        Draft note:
        You have 40 days left.

        Rewrite this draft in a more personal and encouraging way, keeping the same information.
        """))
    }

    func test_systemInstructions_forLanguage_english_isEnglishAndDoesNotAskForTurkish() {
        let text = CoachPromptBuilder.systemInstructions(for: .english)
        XCTAssertFalse(text.contains("Türkçe"))
        XCTAssertFalse(text.contains("YDS"))
        XCTAssertTrue(text.contains("English learner"))
        XCTAssertEqual(CoachPromptBuilder.systemInstructions(for: .turkish), CoachPromptBuilder.systemInstructions)
    }
}
