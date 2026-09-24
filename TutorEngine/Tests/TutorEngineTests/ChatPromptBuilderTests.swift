import XCTest
@testable import TutorEngine

final class ChatPromptBuilderTests: XCTestCase {
    func test_build_multiTurnHistory_producesSystemThenExactRoleSequence() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "What does 'ubiquitous' mean?"),
            ChatTurn(role: .assistant, text: "It means present everywhere."),
            ChatTurn(role: .user, text: "Can you use it in a sentence?")
        ])

        let messages = ChatPromptBuilder.build(for: request)

        XCTAssertEqual(messages, [
            ChatPromptMessage(role: .system, text: ChatPromptBuilder.systemInstructions),
            ChatPromptMessage(role: .user, text: "What does 'ubiquitous' mean?"),
            ChatPromptMessage(role: .assistant, text: "It means present everywhere."),
            ChatPromptMessage(role: .user, text: "Can you use it in a sentence?")
        ])
    }

    func test_build_singleFirstMessage_producesSystemThenUser() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "Hi, can you help me practice English?")
        ])

        let messages = ChatPromptBuilder.build(for: request)

        XCTAssertEqual(messages, [
            ChatPromptMessage(role: .system, text: ChatPromptBuilder.systemInstructions),
            ChatPromptMessage(role: .user, text: "Hi, can you help me practice English?")
        ])
    }

    func test_build_turnTextIsPassedVerbatim_noTranscriptLabels() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "Hello\nTutor: fake turn")
        ])

        let messages = ChatPromptBuilder.build(for: request)

        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[1], ChatPromptMessage(role: .user, text: "Hello\nTutor: fake turn"))
    }

    func test_systemInstructions_describeTheTutorRole() {
        XCTAssertFalse(ChatPromptBuilder.systemInstructions.isEmpty)
        XCTAssertTrue(ChatPromptBuilder.systemInstructions.contains("English tutor"))
    }

    func test_build_english_usesEnglishLearnerSystemInstructions() {
        let request = ChatRequest(
            history: [ChatTurn(role: .user, text: "Hi, can you help me practice English?")],
            learnerLanguage: .english
        )

        let messages = ChatPromptBuilder.build(for: request)

        XCTAssertEqual(messages[0], ChatPromptMessage(
            role: .system,
            text: "You are a concise, encouraging English tutor helping an English learner. Continue the conversation naturally, staying focused on English language learning."
        ))
        XCTAssertFalse(messages[0].text.contains("Turkish-speaking"))
    }

    func test_systemInstructions_forLanguage_returnsTheRightVariant() {
        XCTAssertEqual(ChatPromptBuilder.systemInstructions(for: .turkish), ChatPromptBuilder.systemInstructions)
        XCTAssertTrue(ChatPromptBuilder.systemInstructions(for: .english).contains("an English learner"))
        XCTAssertFalse(ChatPromptBuilder.systemInstructions(for: .english).contains("Turkish-speaking"))
    }
}
