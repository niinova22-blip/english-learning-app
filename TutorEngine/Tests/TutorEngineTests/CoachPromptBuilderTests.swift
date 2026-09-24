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
}
