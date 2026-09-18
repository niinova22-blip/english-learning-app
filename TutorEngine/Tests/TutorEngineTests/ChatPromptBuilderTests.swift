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
}
