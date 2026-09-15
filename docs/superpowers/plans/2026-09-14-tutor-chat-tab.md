# Standalone Tutor Chat Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a third app tab — a general-purpose, multi-turn English-tutoring chat — reusing the same on-device `MLXTutorEngine` instance and lazy-loading infrastructure the card-scoped tutor already uses, with session-only (non-persisted) conversation memory.

**Architecture:** `TutorEngine` gains a second protocol method (`respond(to: ChatRequest)`) alongside the existing card-scoped one, plus `ChatTurn`/`ChatRequest`/`ChatPromptBuilder` types. `MLXTutorEngine` implements the new method by reusing its existing, already-proven single-string-prompt generation path (`UserInput(prompt:)` → `modelContainer.perform` → `MLXLMCommon.generate`) with `ChatPromptBuilder`-built text instead of `PromptBuilder`-built text — no new external-API risk, since this exact generation mechanism already works in production for the card feature. App-side: a new `ChatViewModel` (message list + loading + history capping + per-message retry), a new `TutorChatView` (chat UI), and a `TutorTabView` wrapper that lazily loads the shared engine and shows a loading/retry state while it does.

**Tech Stack:** Swift 5.10+, SwiftUI, the existing `mlx-swift-examples` dependency (no new dependency — this plan adds no new external packages).

**Spec:** `docs/superpowers/specs/2026-09-14-tutor-chat-tab-design.md`

## Global Constraints

- No conversation persistence across app launches — `messages` lives only in view/view-model state for the current app session. No SwiftData changes.
- One continuous conversation per session, reset via an explicit "New Chat" action — no multiple saved conversation threads.
- No dependency from `TutorEngine` on `LearningEngine` — this chat has no access to the learner's vocabulary/lesson content, by design (see spec's Non-goals).
- No streaming — a complete response is shown once generation finishes, same as the card feature.
- The existing card-scoped `TutorSheetView`, `TutorViewModel`, `TutorRequest`, `PromptBuilder`, and `QuickAction` are untouched by this plan — this work is purely additive.
- Reuse the single already-loaded `MLXTutorEngine` instance (via `AppState.tutorEngine`) for both features — never construct a second engine/load the model twice.
- Tutor tab visibility uses the same `AppState.isTutorAvailable` check the card feature already uses — no second availability check invented.
- This dev machine has no Swift/Xcode toolchain at all — all verification goes through `bash scripts/ci-test.sh` (for `TutorEngine`'s own `swift test`) and `bash scripts/ci-app-build.sh` (for the App target, ~10-15 minutes per run since it resolves the MLX dependency graph and fetches the model).
- Per this feature family's established, accepted gap: `MLXTutorEngine`'s real generation (including the new chat method) is not exercised by an automated test — verified by compilation + no regression, not a new generation test.

---

### Task 1: TutorEngine package — chat types, prompt builder, protocol method, MLXTutorEngine implementation

**Files:**
- Create: `TutorEngine/Sources/TutorEngine/ChatRequest.swift`
- Modify: `TutorEngine/Sources/TutorEngine/TutorRequest.swift` (add one protocol method to the existing `TutorEngine` protocol)
- Modify: `TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift` (implement the new protocol method)
- Create: `TutorEngine/Tests/TutorEngineTests/ChatPromptBuilderTests.swift`

**Interfaces:**
- Produces: `ChatTurn` (struct: `role: Role`, `text: String`; `Role` enum `.user`/`.assistant`), `ChatRequest` (struct: `history: [ChatTurn]`), `ChatPromptBuilder.build(for: ChatRequest) -> String`, `TutorEngine.respond(to: ChatRequest) async throws -> String` (new protocol requirement), `MLXTutorEngine`'s conformance to it.

This task adds the new protocol method AND its `MLXTutorEngine` implementation together, in one task — never split across two commits/tasks, because adding a new protocol requirement without also implementing it on `MLXTutorEngine` (the package's only conforming type) would leave the package failing to compile between commits.

- [ ] **Step 1: Write the failing tests**

`TutorEngine/Tests/TutorEngineTests/ChatPromptBuilderTests.swift`:

```swift
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
```

- [ ] **Step 2: Confirm the tests would fail**

This dev machine has no Swift toolchain — there is no local RED run to execute. `ChatRequest`/`ChatTurn`/`ChatPromptBuilder` don't exist yet at this point, so this test file cannot compile — that's the expected RED state. The real, binding verification of both RED-would-happen and GREEN-does-happen is the CI run in Step 4.

- [ ] **Step 3: Implement ChatTurn, ChatRequest, ChatPromptBuilder**

`TutorEngine/Sources/TutorEngine/ChatRequest.swift`:

```swift
import Foundation

/// One turn in a multi-turn tutor conversation.
public struct ChatTurn: Sendable, Equatable {
    public enum Role: Sendable, Equatable {
        case user
        case assistant
    }

    public let role: Role
    public let text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

/// A general-purpose, multi-turn tutor conversation. `history`'s last
/// element is the learner's newest message; every earlier element is a
/// prior turn in the same conversation. Capping how much history is
/// included is the caller's responsibility (see `ChatViewModel` in the
/// App target) — this type makes no assumption about length.
public struct ChatRequest: Sendable, Equatable {
    public let history: [ChatTurn]

    public init(history: [ChatTurn]) {
        self.history = history
    }
}

/// Turns a `ChatRequest` into a single text prompt. Pure and
/// deterministic, like `PromptBuilder`. `MLXTutorEngine` uses this to
/// build its generation prompt via the same proven single-string-prompt
/// path already used for card-scoped asks.
public enum ChatPromptBuilder {
    public static func build(for request: ChatRequest) -> String {
        var prompt = "You are a concise, encouraging English tutor helping a Turkish-speaking learner. Continue the conversation naturally, staying focused on English language learning.\n\n"

        for turn in request.history {
            switch turn.role {
            case .user:
                prompt += "Learner: \(turn.text)\n"
            case .assistant:
                prompt += "Tutor: \(turn.text)\n"
            }
        }

        prompt += "Tutor:"
        return prompt
    }
}
```

- [ ] **Step 4: Wire in CI and run the tests**

No new CI step is needed — `.github/workflows/swift-tests.yml` already runs `swift test --parallel` inside `TutorEngine/`, which will pick up `ChatPromptBuilderTests.swift` automatically.

Run: `bash scripts/ci-test.sh`
Expected: PASS — the run must show the new `ChatPromptBuilderTests` (4 tests) passing alongside the existing `PromptBuilderTests`. This will currently FAIL to even compile, because `TutorEngine`'s protocol doesn't yet have the new method and `MLXTutorEngine` doesn't yet conform — proceed to Steps 5-6 before this can go green, then come back and run this.

- [ ] **Step 5: Add the protocol method**

`TutorEngine/Sources/TutorEngine/TutorRequest.swift` — add one line to the existing protocol (leave everything else in the file unchanged):

```swift
public protocol TutorEngine {
    func respond(to request: TutorRequest) async throws -> String
    func respond(to chat: ChatRequest) async throws -> String
}
```

- [ ] **Step 6: Implement it on MLXTutorEngine**

`TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift` — add a new method to the existing `actor MLXTutorEngine`, reusing the exact same generation mechanism the existing `respond(to: TutorRequest)` method already uses (just with `ChatPromptBuilder` instead of `PromptBuilder`):

```swift
    public func respond(to chat: ChatRequest) async throws -> String {
        let prompt = ChatPromptBuilder.build(for: chat)
        let userInput = UserInput(prompt: prompt)
        let generateParameters = generateParameters

        return try await modelContainer.perform { context in
            let lmInput = try await context.processor.prepare(input: userInput)
            let result = try MLXLMCommon.generate(
                input: lmInput, parameters: generateParameters, context: context
            ) { (_: [Int]) in .more }
            return result.output
        }
    }
```

This duplicates the shape of `respond(to: TutorRequest)`'s body almost exactly (both end up as "build a string prompt, run the same generation call") — that's expected and fine here: extracting a shared private helper is a reasonable follow-up but not required by this task, since the two call sites differ only in which prompt builder they call, and forcing an abstraction over a two-line body for two call sites would be premature. If a third call site for this pattern ever appears, that's the signal to extract it.

- [ ] **Step 7: Run tests to verify they pass**

Run: `bash scripts/ci-test.sh`
Expected: PASS — all 4 new `ChatPromptBuilderTests` green, plus all existing `PromptBuilderTests` still passing, plus `TutorEngine` (including `MLXTutorEngine`) compiling successfully with the new protocol method implemented.

If the real, currently-resolved `mlx-swift-examples`/`MLXLMCommon` API has changed since the card feature's own implementation (unlikely within the same pinned `2.29.1` version, but possible if anything about `UserInput`/`generate` was adjusted since) and this doesn't compile as written, adapt to the real compiler error — same "adapt to the real environment" approach already used successfully multiple times for this exact dependency.

- [ ] **Step 8: Commit**

```bash
git add TutorEngine/Sources/TutorEngine/ChatRequest.swift TutorEngine/Sources/TutorEngine/TutorRequest.swift TutorEngine/Sources/TutorEngine/MLXTutorEngine.swift TutorEngine/Tests/TutorEngineTests/ChatPromptBuilderTests.swift
git commit -m "Add multi-turn chat support to TutorEngine: ChatRequest, ChatPromptBuilder, MLXTutorEngine.respond(to: ChatRequest)"
```

---

### Task 2: ChatViewModel

**Files:**
- Create: `App/Sources/EnglishApp/Tutor/ChatViewModel.swift`
- Create: `App/Tests/EnglishAppTests/ChatViewModelTests.swift`

**Interfaces:**
- Consumes: `TutorEngine` protocol, `ChatTurn`, `ChatRequest` (Task 1)
- Produces: `ChatViewModel` (class, `@MainActor @Observable`), `ChatViewModel.DisplayMessage` (struct: `id: UUID`, `turn: ChatTurn`, `failed: Bool`), `messages: [DisplayMessage]`, `isLoading: Bool`, `send(_ text: String) async`, `retryLastMessage() async`, `startNewChat()`

- [ ] **Step 1: Write the failing tests**

`App/Tests/EnglishAppTests/ChatViewModelTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash scripts/ci-app-build.sh`
Expected: FAIL — `ChatViewModel` doesn't exist yet (compile error). This machine can't run `xcodebuild test` locally, so this "red" step is confirmed via CI, same as every other App-target test in this project.

- [ ] **Step 3: Implement ChatViewModel**

`App/Sources/EnglishApp/Tutor/ChatViewModel.swift`:

```swift
import Foundation
import TutorEngine

@MainActor
@Observable
final class ChatViewModel {
    struct DisplayMessage: Identifiable, Equatable {
        let id: UUID
        var turn: ChatTurn
        var failed: Bool = false
    }

    private(set) var messages: [DisplayMessage] = []
    private(set) var isLoading = false
    private let engine: any TutorEngine
    private let historyCap: Int

    init(engine: any TutorEngine, historyCap: Int = 20) {
        self.engine = engine
        self.historyCap = historyCap
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .user, text: trimmed)))
        await requestResponse()
    }

    func retryLastMessage() async {
        guard let last = messages.last, last.turn.role == .user, last.failed else { return }
        messages[messages.count - 1].failed = false
        await requestResponse()
    }

    func startNewChat() {
        messages = []
    }

    private func requestResponse() async {
        isLoading = true
        defer { isLoading = false }

        let cappedHistory = messages.suffix(historyCap).map(\.turn)
        do {
            let reply = try await engine.respond(to: ChatRequest(history: Array(cappedHistory)))
            messages.append(DisplayMessage(id: UUID(), turn: ChatTurn(role: .assistant, text: reply)))
        } catch {
            if let lastIndex = messages.indices.last, messages[lastIndex].turn.role == .user {
                messages[lastIndex].failed = true
            }
        }
    }
}
```

`historyCap` defaults to 20 (an implementation-time constant per the spec, to be revisited once real on-device generation latency is measured) — the last 20 *displayed* messages (user + assistant turns combined) are sent as context, not the last 20 user messages; this is a deliberate simplicity choice consistent with the spec's "keep the most recent N turns" framing.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS — all 6 new `ChatViewModelTests` green, plus every pre-existing App test (including `TutorViewModelTests`) still passing.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/Tutor/ChatViewModel.swift App/Tests/EnglishAppTests/ChatViewModelTests.swift
git commit -m "Add ChatViewModel"
```

---

### Task 3: TutorChatView, TutorTabView, and RootTabView integration

**Files:**
- Create: `App/Sources/EnglishApp/Tutor/TutorChatView.swift`
- Create: `App/Sources/EnglishApp/Tutor/TutorTabView.swift`
- Modify: `App/Sources/EnglishApp/RootTabView.swift`

**Interfaces:**
- Consumes: `ChatViewModel` (Task 2), `AppState.isTutorAvailable`, `AppState.tutorEngine`, `AppState.loadTutorEngineIfNeeded()` (already exist, from the local-tutor-llm slice and its follow-up)

This is the final task: it wires the chat feature into the actual app UI. `TutorChatView` always has a real, already-loaded engine (mirroring `TutorSheetView`'s existing pattern); `TutorTabView` is the thin wrapper that bridges "engine not loaded yet" to "engine ready," including a retry affordance if loading genuinely fails (not an infinite spinner) — this closes a small gap the card feature doesn't need to handle the same way, since a tab that's already visible needs *something* to show while/if loading is in progress or fails, unlike a button that can simply stay tappable.

- [ ] **Step 1: Write TutorChatView**

`App/Sources/EnglishApp/Tutor/TutorChatView.swift`:

```swift
import SwiftUI
import TutorEngine

struct TutorChatView: View {
    @State private var viewModel: ChatViewModel
    @State private var draftText = ""

    init(engine: any TutorEngine) {
        _viewModel = State(initialValue: ChatViewModel(engine: engine))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle("Tutor")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chat") { viewModel.startNewChat() }
                }
            }
        }
    }

    private var messageList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.messages) { message in
                    messageRow(message)
                }
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding()
        }
    }

    private func messageRow(_ message: ChatViewModel.DisplayMessage) -> some View {
        HStack {
            if message.turn.role == .assistant {
                bubble(for: message)
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble(for: message)
            }
        }
    }

    private func bubble(for message: ChatViewModel.DisplayMessage) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.turn.text)
                .padding(10)
                .background(
                    message.turn.role == .user
                        ? Color.blue.opacity(0.15)
                        : Color.gray.opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if message.failed {
                Button("Retry") { Task { await viewModel.retryLastMessage() } }
                    .font(.caption)
            }
        }
    }

    private var inputBar: some View {
        HStack {
            TextField("Ask your tutor...", text: $draftText)
                .textFieldStyle(.roundedBorder)
            Button("Send") {
                let text = draftText
                draftText = ""
                Task { await viewModel.send(text) }
            }
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
        }
        .padding()
    }
}
```

- [ ] **Step 2: Write TutorTabView**

`App/Sources/EnglishApp/Tutor/TutorTabView.swift`:

```swift
import SwiftUI

/// Bridges "the shared tutor engine hasn't been loaded yet" to
/// `TutorChatView`, which always requires a real, already-loaded
/// engine (mirroring `TutorSheetView`'s existing pattern in the
/// card-scoped feature). Shown only when `AppState.isTutorAvailable`
/// is true (see `RootTabView`) — this view's own states are about
/// "available but not yet loaded" / "available but failed to load",
/// never about total unavailability, which is handled by hiding the
/// tab entirely one level up.
struct TutorTabView: View {
    @Environment(AppState.self) private var appState
    @State private var isLoading = false
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let engine = appState.tutorEngine {
                TutorChatView(engine: engine)
            } else if isLoading {
                ProgressView("Loading tutor...")
            } else {
                VStack(spacing: 12) {
                    if loadFailed {
                        Text("Couldn't load the tutor.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Load Tutor") { Task { await load() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard appState.tutorEngine == nil, !isLoading else { return }
        isLoading = true
        await appState.loadTutorEngineIfNeeded()
        isLoading = false
        loadFailed = appState.tutorEngine == nil
    }
}
```

- [ ] **Step 3: Wire the third tab into RootTabView**

`App/Sources/EnglishApp/RootTabView.swift` (replace the whole file):

```swift
import SwiftUI

struct RootTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }
            if appState.isTutorAvailable {
                TutorTabView()
                    .tabItem { Label("Tutor", systemImage: "bubble.left.and.bubble.right") }
            }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
```

(`isTutorAvailable` is a cheap, synchronous check — no `.task` needed at this level; `TutorTabView` handles its own loading trigger.)

- [ ] **Step 4: Verify via CI**

Run: `bash scripts/ci-app-build.sh`
Expected: PASS — app builds, all existing tests (including `ChatViewModelTests` and `TutorViewModelTests`) pass. This does not prove the tab actually appears/works correctly on a real device with the real model loaded (per this feature family's established, accepted gap) — it proves the wiring compiles and degrades gracefully.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/EnglishApp/Tutor/TutorChatView.swift App/Sources/EnglishApp/Tutor/TutorTabView.swift App/Sources/EnglishApp/RootTabView.swift
git commit -m "Add standalone Tutor chat tab"
```

## Future work this unblocks

- Persisting conversation history across app launches (a real SwiftData addition).
- Multiple named/saved conversations, once persistence exists.
- Streaming responses (shared with the card feature's own deferred streaming work).
- Manual on-device verification of real multi-turn generation quality and the `historyCap` constant's tuning, alongside the card feature's already-known "real latency tuning happens on real hardware" gap.
