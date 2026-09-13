import XCTest
import TutorEngine
@testable import EnglishApp

private final class FakeChatEngine: TutorEngine {
    var stubbedReply = "stub reply"
    var stubbedError: Error?
    private(set) var lastChatRequest: ChatRequest?
    private(set) var chatRequestCount = 0

    func respond(to request: TutorRequest) async throws -> String {
        fatalError("not used by ChatViewModelTests")
    }

    func respond(to chat: ChatRequest) async throws -> String {
        lastChatRequest = chat
        chatRequestCount += 1
        if let stubbedError { throw stubbedError }
        return stubbedReply
    }
}

private struct StubChatError: Error {}

@MainActor
final class ChatViewModelTests: XCTestCase {
    func test_send_appendsUserMessageAndAssistantReply() async {
        let engine = FakeChatEngine()
        engine.stubbedReply = "Here's my answer."
        let viewModel = ChatViewModel(engine: engine)

        await viewModel.send("What does 'ubiquitous' mean?")

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].turn.role, .user)
        XCTAssertEqual(viewModel.messages[0].turn.text, "What does 'ubiquitous' mean?")
        XCTAssertEqual(viewModel.messages[1].turn.role, .assistant)
        XCTAssertEqual(viewModel.messages[1].turn.text, "Here's my answer.")
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_send_ignoresBlankInput() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        await viewModel.send("   ")

        XCTAssertEqual(viewModel.messages.count, 0)
        XCTAssertEqual(engine.chatRequestCount, 0)
    }

    func test_send_onFailure_marksLastMessageFailed() async {
        let engine = FakeChatEngine()
        engine.stubbedError = StubChatError()
        let viewModel = ChatViewModel(engine: engine)

        await viewModel.send("Hello")

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].turn.role, .user)
        XCTAssertTrue(viewModel.messages[0].failed)
    }

    func test_retryLastMessage_clearsFailureAndRetriesSuccessfully() async {
        let engine = FakeChatEngine()
        engine.stubbedError = StubChatError()
        let viewModel = ChatViewModel(engine: engine)
        await viewModel.send("Hello")
        XCTAssertTrue(viewModel.messages[0].failed)

        engine.stubbedError = nil
        engine.stubbedReply = "Hi! How can I help?"
        await viewModel.retryLastMessage()

        XCTAssertFalse(viewModel.messages[0].failed)
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].turn.text, "Hi! How can I help?")
    }

    func test_historyCap_limitsSentHistoryButNotDisplayedMessages() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine, historyCap: 2)

        await viewModel.send("first")
        await viewModel.send("second")
        await viewModel.send("third")

        // 3 sends × 2 messages each (user + assistant) = 6 displayed messages.
        XCTAssertEqual(viewModel.messages.count, 6)
        // But the last request's history must be capped to 2 entries.
        XCTAssertEqual(engine.lastChatRequest?.history.count, 2)
    }

    func test_startNewChat_clearsMessages() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine)
        await viewModel.send("Hello")
        XCTAssertFalse(viewModel.messages.isEmpty)

        viewModel.startNewChat()

        XCTAssertTrue(viewModel.messages.isEmpty)
    }
}
