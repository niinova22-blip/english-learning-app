# Standalone Tutor Chat Tab — Design Spec

Date: 2026-09-14
Status: Approved for implementation planning
Slice: 5 of N (follows learning-engine, app-shell, content-pipeline,
local-tutor-llm; this is the second, previously-deferred half of the
local-tutor-llm slice's own "Future work")

## Context

The local-tutor-llm slice shipped an in-session, card-scoped tutor: a
learner reveals a card in Today and can ask a fixed quick action or a
one-off free-text question about that specific word, with no memory
between asks. That slice's own spec explicitly named a standalone,
general-purpose chat tab with multi-turn memory as a deliberately
separate, later slice. This is that slice.

## Goals

- A third tab ("Tutor") alongside Today and Settings: a general-purpose
  English-tutoring chat, not scoped to any specific card or word.
- Multi-turn conversation: the learner's prior messages and the
  assistant's prior replies are fed back as context for follow-up
  questions within one conversation, unlike the card-scoped assistant's
  single-shot asks.
- One continuous conversation per session, with a "New Chat" action to
  reset it explicitly. No conversation history persists across app
  launches — closing and reopening the app starts fresh.
- Reuses the same `MLXTutorEngine` instance already used by the
  card-scoped feature — the model is loaded once, not once per feature.
  Reuses the same lazy-loading infrastructure (`AppState.isTutorAvailable`
  / `loadTutorEngineIfNeeded()`) introduced as a local-tutor-llm
  follow-up: entering the tab triggers the load if it hasn't happened
  yet, with a visible loading state, exactly like the card feature's
  first tap.
- Same graceful-degradation philosophy as the rest of this feature
  family: if the tutor isn't available on this device/build (Simulator,
  missing resource, load failure), the tab is hidden entirely — no
  error UI, no partially-working state.

## Non-goals

- No persistence of chat history across app launches. A future slice
  could add this (SwiftData-backed conversation storage) but it isn't
  needed now and would add real schema/migration surface for no
  requested benefit yet.
- No multiple named/saved conversations — one continuous conversation,
  reset via "New Chat." Multiple conversation threads make little sense
  without persistence anyway (they'd all vanish on app restart together).
- No access to the learner's actual vocabulary/lesson history
  (`LearningEngine` content) — this chat is a general English-tutoring
  assistant, not a personalized review companion. `TutorEngine` gains no
  dependency on `LearningEngine`, preserving the separation the original
  spec established.
- No streaming token-by-token responses — same as the card feature,
  a complete response is shown once generation finishes.
- No changes to the card-scoped `TutorSheetView`/`TutorViewModel` or to
  `TutorRequest`/`PromptBuilder`/`QuickAction` — those are untouched;
  this slice is additive.

## Architecture

`TutorEngine` package gains:

- `ChatTurn` — `{ role: Role, text: String }`, `Role` is `.user` or
  `.assistant`. `Sendable`, `Equatable` (matching this package's existing
  types).
- `ChatRequest` — `{ history: [ChatTurn] }`, where `history`'s last
  element is the learner's newest message and every prior element is
  an earlier turn in the same conversation (already capped — see
  "History cap" below; capping is the caller's responsibility, not
  `ChatRequest`'s).
- `TutorEngine` protocol gains a second method:
  `func respond(to chat: ChatRequest) async throws -> String`
  (alongside the existing `func respond(to request: TutorRequest) async
  throws -> String`). One engine, two ways to ask it something — this
  keeps a single loaded model instance serving both features.
- `MLXTutorEngine` implements the new method. The exact way it turns
  `[ChatTurn]` into a real multi-turn prompt for the underlying
  `mlx-swift-examples` API is an implementation-time decision: if
  `MLXLMCommon`'s real API exposes a native multi-turn chat/message
  input (likely, since Llama 3.2 Instruct's chat template has
  system/user/assistant roles), use that directly; if it only exposes a
  single-string prompt (as the card feature's `PromptBuilder` path
  does), build a single formatted transcript string instead. Verify
  against the real, currently-resolved package version — this project's
  established pattern for this exact dependency (see local-tutor-llm's
  Task 2) is to adapt to the real API rather than guess.

App target gains:

- `ChatViewModel` (`@MainActor @Observable`, `App/Sources/EnglishApp/Tutor/`):
  holds `messages: [ChatTurn]` and `isLoading: Bool`; `send(_ text:
  String) async` appends the learner's message, calls
  `engine.respond(to: ChatRequest(history: cappedHistory))`, and appends
  the assistant's reply (or surfaces a per-message failure — see Error
  handling); `startNewChat()` clears `messages`.
- `TutorChatView` (new tab): a scrollable message list (learner's
  messages and the assistant's replies visually distinguished), a
  bottom text field + send button, a "New Chat" toolbar action, and a
  loading indicator while a response is pending.
- `RootTabView` gains a third tab, shown only `if appState.isTutorAvailable`
  (consistent with the card feature's visibility rule — same source of
  truth, no new availability check invented).
- Entering the tab (or the view appearing) triggers
  `await appState.loadTutorEngineIfNeeded()` if `appState.tutorEngine`
  isn't already set, with the tab showing a loading state meanwhile —
  reusing the exact mechanism already built for the card feature's lazy
  load, not a second implementation of it.

## History cap

Feeding unbounded conversation history back into every request would
grow prompts without bound, slowing generation and eventually exceeding
the model's context window. `ChatViewModel` caps how much history it
sends: keep the most recent N turns (an implementation-time constant,
tuned during implementation with a reasonable starting value — e.g.
the last 10-20 turns — and revisited once real on-device generation
latency is actually measured, same as the card feature's already-known
"real latency tuning happens on real hardware" gap). The full
`messages` array shown in the UI is never truncated by this cap — only
what's sent back to the model as context is capped, so the learner
always sees their whole conversation on screen even if older turns stop
being "remembered" by the model.

## Error handling

- **Tutor unavailable** (model can't load): the whole tab is hidden,
  exactly like the card feature's button — never shown-and-broken.
- **A single message's generation fails or times out**: shown inline in
  the chat as a failed message (e.g. an error indicator next to that
  specific learner message) with a retry action for that message only —
  the rest of the conversation is untouched. This does not reset
  `messages` or force "New Chat."

## Testing

- `ChatViewModel`'s state machine (message list growth, loading state,
  new-chat reset, history capping, per-message failure/retry) is
  fully unit-tested using a fake `TutorEngine` (no real model needed),
  the same pattern already used for `TutorViewModelTests`.
- As with the rest of this feature family: `MLXTutorEngine`'s real
  multi-turn generation is not exercised by an automated test — this
  project's accepted, already-established gap (this dev machine can't
  run MLX/Xcode; CI's ability to run real Metal-backed generation is
  unconfirmed) applies here identically.

## Future work this unblocks

- Persisting conversation history across launches (a real SwiftData
  addition, deliberately deferred here).
- Multiple named/saved conversations, once persistence exists.
- Streaming responses (shared with the card feature's own deferred
  streaming work).
