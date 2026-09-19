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

    func respond(to question: QuestionTutorRequest) async throws -> String {
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

/// A `TutorEngine` whose `respond(to chat:)` suspends until the test
/// explicitly resumes it, so tests can observe/control `ChatViewModel`
/// behavior around an in-flight request (overlapping calls, `startNewChat`
/// racing a pending reply, etc). `@MainActor`-isolated so its stored state
/// (`callCount`, the pending continuations) is only ever touched from the
/// same actor as the `@MainActor` test class — a nonisolated async method
/// on a plain class would run off the main actor under SE-0338 and race
/// the test's own reads/writes.
///
/// Continuations are resumed FIFO (oldest call first), which is what lets
/// a test simulate "an earlier, now-stale request finally comes back after
/// a newer request is already in flight."
@MainActor
private final class ControllableChatEngine: TutorEngine {
    private(set) var callCount = 0
    private(set) var lastChatRequest: ChatRequest?
    private var pendingContinuations: [CheckedContinuation<String, Error>] = []

    func respond(to request: TutorRequest) async throws -> String {
        fatalError("not used by ChatViewModelTests")
    }

    func respond(to question: QuestionTutorRequest) async throws -> String {
        fatalError("not used by ChatViewModelTests")
    }

    func respond(to chat: ChatRequest) async throws -> String {
        lastChatRequest = chat
        callCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuations.append(continuation)
        }
    }

    /// Waits, via a bounded `Task.yield()` loop (never `Task.sleep`), until
    /// `respond(to:)` has been called at least `count` times.
    func waitUntilCalled(_ count: Int) async {
        var iterations = 0
        while callCount < count {
            await Task.yield()
            iterations += 1
            if iterations > 10_000 {
                XCTFail("ControllableChatEngine.respond(to:) was not called \(count) time(s) in time")
                return
            }
        }
    }

    func resume(returning reply: String) {
        guard !pendingContinuations.isEmpty else {
            XCTFail("No pending ControllableChatEngine call to resume")
            return
        }
        pendingContinuations.removeFirst().resume(returning: reply)
    }

    func resume(throwing error: Error) {
        guard !pendingContinuations.isEmpty else {
            XCTFail("No pending ControllableChatEngine call to resume")
            return
        }
        pendingContinuations.removeFirst().resume(throwing: error)
    }
}

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

    func test_historyCap_limitsSentHistoryToMostRecentTurnsButNotDisplayedMessages() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine, historyCap: 3)

        engine.stubbedReply = "reply 1"
        await viewModel.send("first")
        engine.stubbedReply = "reply 2"
        await viewModel.send("second")
        engine.stubbedReply = "reply 3"
        await viewModel.send("third")

        // 3 sends × 2 messages each (user + assistant) = 6 displayed messages.
        XCTAssertEqual(viewModel.messages.count, 6)
        // The last request (sent when messages were first…third) must keep
        // the MOST RECENT 3 turns, in order — not the oldest.
        XCTAssertEqual(engine.lastChatRequest?.history, [
            ChatTurn(role: .user, text: "second"),
            ChatTurn(role: .assistant, text: "reply 2"),
            ChatTurn(role: .user, text: "third")
        ])
    }

    func test_historyCap_whenCappedHistoryStartsWithAssistant_dropsThatTurn() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine, historyCap: 2)

        engine.stubbedReply = "reply 1"
        await viewModel.send("first")
        engine.stubbedReply = "reply 2"
        await viewModel.send("second")
        await viewModel.send("third")

        // suffix(2) of [first, reply 1, second, reply 2, third] is
        // [reply 2, third]; the leading assistant turn must be dropped so
        // the context starts with a learner turn.
        XCTAssertEqual(engine.lastChatRequest?.history, [
            ChatTurn(role: .user, text: "third")
        ])
        XCTAssertEqual(viewModel.messages.count, 6)
    }

    func test_send_afterFailedMessage_excludesFailedMessageFromSentHistory() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        engine.stubbedReply = "reply 1"
        await viewModel.send("first")
        engine.stubbedError = StubChatError()
        await viewModel.send("never answered")
        XCTAssertTrue(viewModel.messages[2].failed)

        // Instead of retrying, the learner sends a new message.
        engine.stubbedError = nil
        engine.stubbedReply = "reply 2"
        await viewModel.send("new question")

        XCTAssertEqual(engine.lastChatRequest?.history, [
            ChatTurn(role: .user, text: "first"),
            ChatTurn(role: .assistant, text: "reply 1"),
            ChatTurn(role: .user, text: "new question")
        ])
        // The failed message is still displayed, with its failure indicator.
        XCTAssertEqual(viewModel.messages.map(\.turn.text), ["first", "reply 1", "never answered", "new question", "reply 2"])
        XCTAssertTrue(viewModel.messages[2].failed)
    }

    func test_retryLastMessage_includesTheRetriedMessageInSentHistory() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine)
        engine.stubbedError = StubChatError()
        await viewModel.send("Hello")

        engine.stubbedError = nil
        await viewModel.retryLastMessage()

        XCTAssertEqual(engine.lastChatRequest?.history, [
            ChatTurn(role: .user, text: "Hello")
        ])
    }

    func test_startNewChat_clearsMessages() async {
        let engine = FakeChatEngine()
        let viewModel = ChatViewModel(engine: engine)
        await viewModel.send("Hello")
        XCTAssertFalse(viewModel.messages.isEmpty)

        viewModel.startNewChat()

        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func test_send_whileInFlight_isIgnored() async {
        let engine = ControllableChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        let firstTask = Task { await viewModel.send("first") }
        await engine.waitUntilCalled(1)

        // A second send while the first is still in flight must be a no-op:
        // no new user message appended, no new engine call.
        await viewModel.send("second")
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(engine.callCount, 1)

        engine.resume(returning: "reply")
        await firstTask.value

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].turn.text, "reply")
        XCTAssertFalse(viewModel.isLoading)
    }

    /// Smoke test only — NOT coverage of `retryLastMessage`'s `!isLoading`
    /// guard. While a request is in flight the last message is never
    /// failed, so the `last.failed` check alone already makes this call a
    /// no-op; through the public API there is no way to reach "failed last
    /// message while loading", so the guard is purely defensive and this
    /// test would still pass without it.
    func test_retryLastMessage_whileInFlight_smoke_startsNoSecondRequest() async {
        let engine = ControllableChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        let firstTask = Task { await viewModel.send("first") }
        await engine.waitUntilCalled(1)

        await viewModel.retryLastMessage()
        XCTAssertEqual(engine.callCount, 1)

        engine.resume(returning: "reply")
        await firstTask.value

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_startNewChat_duringInFlightRequest_discardsStaleSuccess() async {
        let engine = ControllableChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        let task = Task { await viewModel.send("first") }
        await engine.waitUntilCalled(1)

        viewModel.startNewChat()
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)

        // The stale request finally resolves successfully, but its epoch no
        // longer matches — the reply must be discarded, not appended into
        // the fresh conversation.
        engine.resume(returning: "stale reply")
        await task.value

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_startNewChat_duringInFlightRequest_discardsStaleFailure_andNewSendWorks() async {
        let engine = ControllableChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        let task = Task { await viewModel.send("first") }
        await engine.waitUntilCalled(1)

        viewModel.startNewChat()

        // The stale request finally fails, but its epoch no longer
        // matches — nothing should be marked failed (there's nothing left
        // to mark: the conversation was cleared), and isLoading must not
        // be touched by this stale completion.
        engine.resume(throwing: StubChatError())
        await task.value

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)

        // A fresh send in the new conversation must work normally.
        let secondTask = Task { await viewModel.send("second") }
        await engine.waitUntilCalled(2)
        engine.resume(returning: "new reply")
        await secondTask.value

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].turn.text, "second")
        XCTAssertFalse(viewModel.messages[0].failed)
        XCTAssertEqual(viewModel.messages[1].turn.text, "new reply")
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_staleSuccessArrivesWhileNewRequestInFlight_onlyNewReplyLands() async {
        let engine = ControllableChatEngine()
        let viewModel = ChatViewModel(engine: engine)

        let firstTask = Task { await viewModel.send("first") }
        await engine.waitUntilCalled(1)

        viewModel.startNewChat()

        let secondTask = Task { await viewModel.send("second") }
        await engine.waitUntilCalled(2)

        // Resolve the stale first (pre-New-Chat) request while the second,
        // current-epoch request is still in flight. Its reply must be
        // dropped entirely, and it must not touch isLoading — the second
        // request still owns that flag.
        engine.resume(returning: "stale reply")
        await firstTask.value

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].turn.text, "second")
        XCTAssertTrue(viewModel.isLoading)

        engine.resume(returning: "new reply")
        await secondTask.value

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[1].turn.text, "new reply")
        XCTAssertFalse(viewModel.isLoading)
    }
}
