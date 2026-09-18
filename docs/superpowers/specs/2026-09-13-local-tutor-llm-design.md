# On-Device Tutor (Local LLM) — Design Spec

Date: 2026-09-13
Status: Approved for implementation planning
Slice: 4 of N (follows learning-engine, app-shell, content-pipeline)

## Context

The app now has a real FSRS-driven review session (Today tab) fed by a
real 120-word content package, but the only help a learner gets on a
card is what's already printed on it (definition, example sentences,
translation). This slice adds an in-session, on-device tutoring
assistant: a small local language model the learner can ask to explain
a word differently, give another example, or answer a free-form
question about the current card — entirely offline, with no per-request
network call or third-party API.

This is deliberately the first of two tutoring-related slices. A
second, later slice will add a standalone general-purpose chat tab
reusing the same underlying engine; it is out of scope here (see
Non-goals).

## Goals

- A new `TutorEngine` Swift package (sibling to `LearningEngine`) that
  loads a small on-device instruction-tuned language model and can
  generate a short response given a prompt built from the current
  card's content and a learner action.
- MLX Swift (Apple's own on-device ML framework) as the inference
  runtime, running a ~3B-parameter, 4-bit-quantized instruction model.
- Two ways to ask, both available from the first version:
  - **Quick actions** — a small fixed set of buttons ("Explain more
    simply", "Give another example sentence", "How is this different
    from similar words?") that need no typing.
  - **Free-text question** — a text field for anything else the
    learner wants to ask about the current word/context.
- Integration into `TodayView`: once a card's answer is revealed, an
  "Ask Tutor" entry point opens a sheet scoped to that card's content.
- The model ships inside the installed app (not downloaded at runtime)
  so the feature works fully offline from first launch — but the
  ~1.5–2GB weight file is fetched by a build-time script from a pinned
  Hugging Face source rather than committed to git (see Model
  delivery).
- Broad device compatibility is a priority over maximum model quality
  — this is why MLX Swift + an open weight file was chosen over
  Apple's Foundation Models framework (which would restrict the
  feature to Apple Intelligence-capable hardware and iOS 26+, while
  this app's baseline target is iOS 17).

## Non-goals

- No standalone chat tab in this slice — that is a separate future
  slice reusing `TutorEngine`.
- No speech/pronunciation practice — a different, already-planned
  future slice with its own (speech recognition) requirements.
- No streaming token-by-token UI in v1 — the sheet shows a loading
  state and then the complete response. Streaming can be added later
  without changing `TutorEngine`'s public shape meaningfully.
- No conversation memory across questions — each ask is independent,
  scoped only to the current card's content plus the one
  question/action asked. No chat history is persisted or fed back in.
- No changes to `LearningEngine`'s FSRS scheduling, review logging, or
  SwiftData schema — tutoring is help, not a review event, and is not
  recorded as one.
- No automated CI verification of actual model output quality or of
  MLX inference itself succeeding on a real device — see Testing.

## Architecture

A new SPM package, `TutorEngine/`, structured like `LearningEngine`
(plain Swift, unit-testable without Xcode via `swift test`):

- `TutorRequest` — the current card's `headword`, `definition`,
  `exampleSentences`, `translationTR`, plus either a `QuickAction` case
  (`.simplerExplanation`, `.anotherExample`, `.compareToSimilarWords`)
  or a `.freeText(String)` question.
- `PromptBuilder` — a pure function, `build(for: TutorRequest) -> String`,
  turning a request into the actual model prompt (short system
  instruction + the card's context + the specific ask). Pure and fully
  unit-tested; this is where prompt-quality iteration happens without
  touching the model-loading code at all.
- `TutorEngine` (protocol) — `func respond(to: TutorRequest) async throws -> String`.
- `MLXTutorEngine` (concrete, MLX-Swift-backed) — loads the bundled
  model once (an actor, so concurrent asks are serialized rather than
  racing the same model state), and implements `respond(to:)` by
  building the prompt via `PromptBuilder` and running MLX generation.

The App target:

- Depends on `TutorEngine` the same way it already depends on
  `LearningEngine`.
- Bundles the model weight file(s) + tokenizer config under
  `App/Sources/EnglishApp/Resources/TutorModel/`, wired into
  `App/project.yml`'s existing `resources:` entry (same mechanism
  already used for the JSON content package).
- Adds `TutorViewModel` (loading/response/error state for one open
  sheet) and `TutorSheetView` (SwiftUI: quick-action buttons, free-text
  field, response text, loading indicator, error + retry).
- `TodayView`'s revealed-answer state gains an "Ask Tutor" button that
  presents `TutorSheetView`, constructing its `TutorRequest` from the
  current item's `ItemContent`.
- `MLXTutorEngine` is constructed once (e.g. lazily on `AppModelContainer`
  or a small app-level singleton/environment value) and reused across
  asks/sessions rather than reloading the model every time a sheet
  opens.

## Model delivery

The model is `mlx-community/Llama-3.2-3B-Instruct-4bit` — a pinned,
specific MLX-format checkpoint from the `mlx-community` organization on
Hugging Face (Meta's Llama 3.2 3B Instruct, community-converted and
4-bit quantized for MLX). The fetch script pins an exact revision
(commit hash or tag), not a moving branch, so builds are reproducible.
If real-device testing during implementation shows this specific
checkpoint is unavailable or unsuitable, swapping to a different
`mlx-community` checkpoint of the same size class is a fetch-script
and prompt-tuning change only — it does not affect `TutorEngine`'s
public shape.

The weight files are **not committed to git**: a ~1.5–2GB binary
would exceed GitHub's 100MB per-file limit and bloat this public
repo's history indefinitely; Git LFS would avoid the size limit but
adds ongoing bandwidth-quota risk for a public repo. Instead:

- `scripts/fetch-tutor-model.sh` downloads the pinned model's files
  into `App/Sources/EnglishApp/Resources/TutorModel/` if not already
  present (content-addressed or version-pinned so it's a no-op on a
  cache hit).
- This script runs as a step before the Xcode build in both
  `scripts/ci-app-build.sh` and local development — the same "fetch
  before build" shape already used for nothing else in this repo yet,
  but analogous to how any dependency-fetching build step works.
- `App/Sources/EnglishApp/Resources/TutorModel/` is git-ignored.
- End users still experience the feature as fully bundled/offline —
  the fetch happens at build time (developer machine or CI), never on
  the installed app.

## Data flow

1. Learner reveals a card's answer in `TodayView` and taps "Ask Tutor"
   (or, in the sheet, taps a quick action / types a free-text
   question).
2. `TutorSheetView` builds a `TutorRequest` from the current
   `ItemContent` plus the chosen action or typed text.
3. `TutorViewModel` calls the shared `TutorEngine.respond(to:)`,
   tracking a loading state.
4. `MLXTutorEngine` builds the prompt via `PromptBuilder` and runs
   generation on its actor, off the main thread.
5. The response string is shown in the sheet. Nothing is persisted —
   this is ephemeral help, unrelated to FSRS review state or
   `ReviewLog`.

## Error handling

- **Model unavailable** (resource missing/corrupt, or the current
  device/OS combination can't run it at all): detected once, lazily,
  the first time the tutor is needed. When unavailable, the "Ask
  Tutor" entry point is hidden entirely rather than shown and failing
  — the rest of the session (card review, rating, FSRS scheduling) is
  completely unaffected either way.
- **Generation failure or timeout for a single ask**: shown as an
  inline error inside the open sheet with a retry action; never
  surfaces as a session-level error or blocks rating/advancing to the
  next card.

## Testing

- `PromptBuilder`, `TutorRequest`, and `TutorViewModel`'s
  loading/response/error state machine are fully unit-tested using a
  fake `TutorEngine` (no real model needed) — these tests run in CI
  exactly like every other Swift test in this project.
- `MLXTutorEngine` itself (real model loading + generation) is **not**
  exercised by an automated test in this slice: this development
  machine is Windows (can't run MLX/Xcode at all), and it's an open
  question whether GitHub Actions' macOS Simulator runners can execute
  Metal-backed MLX inference reliably or efficiently. This is a known,
  accepted gap — consistent with this project's existing pattern where
  CI-green means "compiles and the mockable logic passes," and genuine
  on-device behavior is confirmed manually later (the same deferred-to-
  real-device verification already used for the rest of this app,
  ahead of the eventual Codemagic/TestFlight step). It is not a blocker
  for building this feature now.

## Future work this unblocks

- A standalone general-purpose "Tutor" chat tab, reusing `TutorEngine`
  and `PromptBuilder` with a conversational (multi-turn, session-scoped
  memory) request shape instead of the single-card-scoped one here.
- Streaming responses (token-by-token) instead of wait-then-show.
- Swapping in a larger or smaller model file if real-device testing
  shows the chosen size is under- or over-provisioned for quality vs.
  compatibility.
