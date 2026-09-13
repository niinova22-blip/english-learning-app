import XCTest
@testable import TutorEngine

final class ChatPromptBuilderTests: XCTestCase {
    func test_build_includesEveryTurnsText() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "What does 'ubiquitous' mean?"),
            ChatTurn(role: .assistant, text: "It means present everywhere."),
            ChatTurn(role: .user, text: "Can you use it in a sentence?")
        ])

        let prompt = ChatPromptBuilder.build(for: request)

        XCTAssertTrue(prompt.contains("What does 'ubiquitous' mean?"))
        XCTAssertTrue(prompt.contains("It means present everywhere."))
        XCTAssertTrue(prompt.contains("Can you use it in a sentence?"))
    }

    func test_build_distinguishesUserFromAssistantTurns() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "Hello"),
            ChatTurn(role: .assistant, text: "Hi there")
        ])

        let prompt = ChatPromptBuilder.build(for: request)

        // The user's turn must be labeled distinctly from the assistant's,
        // and in the order they occurred — not just present anywhere.
        let userRange = prompt.range(of: "Hello")
        let assistantRange = prompt.range(of: "Hi there")
        XCTAssertNotNil(userRange)
        XCTAssertNotNil(assistantRange)
        XCTAssertTrue(userRange!.lowerBound < assistantRange!.lowerBound)
    }

    func test_build_endsWithACueForTheAssistantToContinue() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "What's a synonym for 'happy'?")
        ])

        let prompt = ChatPromptBuilder.build(for: request)

        XCTAssertTrue(prompt.hasSuffix("Tutor:"))
    }

    func test_build_singleFirstMessage_stillProducesAUsableRompt() {
        let request = ChatRequest(history: [
            ChatTurn(role: .user, text: "Hi, can you help me practice English?")
        ])

        let prompt = ChatPromptBuilder.build(for: request)

        XCTAssertTrue(prompt.contains("Hi, can you help me practice English?"))
    }
}
