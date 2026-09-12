# Learning Engine & Content Model — Design Spec

Date: 2026-09-12
Status: Approved for implementation planning
Slice: 1 of N (see "Future slices" below for the rest of the product)

## Context

This is the first buildable slice of a larger iOS English-learning app
(Swift + SwiftUI, freemium + content-package monetization). The full
product vision — content packages (YDS/TOEFL/Business/Conversational),
multimodal lessons, local LLM tutoring, speech/pronunciation practice,
subscriptions — is too large for one spec. This document scopes only
the **core learning engine and content data model**: the piece every
other subsystem (UI, LLM tutoring, analytics) will consume.

Everything here is pure Swift + SwiftData logic. No UIKit/SwiftUI, no
network calls, no LLM calls, no media playback.

## Goals

- A `LearningEngine` local Swift Package containing:
  - The content data model (packages → units → lessons → items)
  - A real **FSRS** (Free Spaced Repetition Scheduler) implementation
  - An **i+1 comprehensible-input** difficulty calculator
  - An **interleaving** daily-session scheduler
- Fully unit-testable via `swift test`, no simulator required.
- Seedable with a small set of hand-authored sample items so the
  engine can be exercised end-to-end before real content exists.

## Non-goals (future slices)

- Real video/audio/transcript content and the pipeline that produces it
- LLM-based bulk content generation (separate spec)
- SwiftUI app shell, navigation, daily-loop screens
- Local LLM tutoring/conversation integration
- Speech-to-text / pronunciation scoring
- Subscriptions, ads, freemium gating enforcement
- iCloud/remote sync

## Architecture

A single local Swift Package, `LearningEngine`, added to the Xcode
project via `File > Add Package Dependency > Add Local...`. The app
target depends on it but the package has no dependency back on the
app. Internal structure:

```
LearningEngine/
  Sources/LearningEngine/
    Models/           # SwiftData @Model types
    FSRS/              # FSRSScheduler + supporting types
    Adaptive/          # ComprehensibleInputCalculator
    Scheduling/        # DailySessionBuilder (interleaving)
    SampleData/        # hand-authored seed content for tests/previews
  Tests/LearningEngineTests/
```

Rationale for a separate package (vs. folders in the app target):
`swift test` runs headless and fast in CI/local dev without booting a
simulator; the boundary forces the engine to stay UI-free, which keeps
it reusable and easy to reason about in isolation, per this project's
"design for isolation" preference.

## Data model (SwiftData `@Model`)

- **ContentPackage** — `id`, `name`, `goal` (enum: `.yds`, `.toefl`,
  `.business`, `.conversational`, `.custom`), `levelRange` (CEFR
  lower/upper bound), ordered `units: [Unit]`.
- **Unit** — belongs to a `ContentPackage`, `theme`, `order`, ordered
  `lessons: [Lesson]`.
- **Lesson** — belongs to a `Unit`, `order`, `estimatedDurationMinutes`,
  ordered `items: [LearningItem]`.
- **LearningItem** — the atomic reviewable unit. `id`, `type` (enum:
  `.vocabulary`, `.grammarPoint`, `.phrase`, `.collocation`),
  `frequencyRank` (Int, for Zipfian ordering), `baseDifficulty`
  (Double, author-set starting difficulty independent of any one
  user's FSRS state), one `ItemContent`.
- **ItemContent** — `definition`, `exampleSentences: [String]`,
  `translationTR`, `collocations: [String]`, optional
  `videoURL`/`audioURL`/`imageURL` (all `nil` until a real media
  pipeline exists — the model must not require them).
- **ReviewLog** — per user, per item: `rating` (enum: `.again`,
  `.hard`, `.good`, `.easy`), `reviewedAt`, `reactionTimeMs`. Append-only
  history; feeds FSRS and future analytics.
- **UserItemState** — per user, per item: FSRS's own state —
  `stability`, `difficulty`, `dueDate`, `reps`, `lapses`,
  `lastReviewedAt`. This is what `FSRSScheduler` reads and writes.

`ContentPackage`/`Unit`/`Lesson`/`LearningItem`/`ItemContent` are
author-time content (shared across all users of a package).
`ReviewLog`/`UserItemState` are per-user learning state. Keeping these
in separate model groups matters once packages are distributed
independently of user progress (e.g. downloaded content updates
shouldn't touch a user's review history).

## FSRS engine

`FSRSScheduler` is a stateless type: given a `UserItemState` (or none,
for a new item) and a `Rating`, it returns the updated
`UserItemState` (new stability, difficulty, due date, reps/lapses).

Implementation must port the actual published FSRS algorithm — the
standard now used by Anki and referenced by open-source implementations
(`py-fsrs`, `rs-fsrs`, `ts-fsrs`) — rather than the simplified
`interval × (3 + difficulty_factor)` sketch from the original product
notes. That sketch is closer to SM-2 and was explicitly rejected in
favor of real FSRS during design.

Resolved during planning: the implementation targets **FSRS-6** (21
parameters), matching the current reference implementation at
`open-spaced-repetition/py-fsrs` (`fsrs/scheduler.py`), fetched and
verified directly from source rather than transcribed from memory. The
default parameter array, the initial-stability/initial-difficulty
formulas, the difficulty mean-reversion update, the post-review and
post-lapse stability formulas, and the retrievability/interval formulas
(driven by a decay/factor pair derived from parameter 20) all follow
that reference exactly. The implementation plan
(`docs/superpowers/plans/2026-09-12-learning-engine.md`) embeds the
verified default weights and hand-computed reference vectors used as
TDD test fixtures. FSRS-6's short-term/same-day stability formula
(parameters 17–19) is intentionally not implemented in this slice,
since the product's daily-loop model reviews each item at most once
per day — noted here so it isn't lost if same-day re-review is added
later.

`FSRSScheduler` also exposes retrievability `R(t)` for a given state,
which the interleaving scheduler uses to prioritize "at risk of being
forgotten" items.

## i+1 comprehensible-input calculator

`ComprehensibleInputCalculator` takes:
- a `UserLevelSnapshot` (known-vocabulary set, rolling comprehension
  accuracy, average reaction time)
- a candidate `LearningItem`

and returns a `DifficultyFit` (`.tooEasy`, `.optimal`, `.tooHard`),
using the thresholds from the product notes (≥85% comprehension →
skip ahead; 70–80% → present as "+1"; ≤50% → fall back to review).
This is the piece the daily-session builder queries when deciding
whether to introduce a new item.

## Interleaving daily-session scheduler

`DailySessionBuilder` combines three sources into one ordered
`[LearningItem]` for a session:

1. FSRS-due items for the user (sorted by lowest retrievability first)
2. Candidate new items scored `.optimal` by the i+1 calculator
3. Topic-mix weighting per the user's current phase:
   - **Blocked** (early): single topic dominates
   - **Hybrid**: primary weak topic ~40%, others fill the rest
   - **Full interleaving**: weighted round-robin favoring the weakest
     topics, capped so no single topic exceeds a configurable share

`DailySessionBuilder` takes the user's current phase and a per-topic
accuracy map (both simple inputs, not computed by the engine itself —
that aggregation can live in a caller/analytics layer later) and
returns the ordered item list. It does not know about UI, sessions
elapsed, or timers.

## Testing strategy

- **FSRS correctness**: unit tests against reference input/output
  vectors from the official FSRS implementation (ports of their test
  suite), not just "does the number go up."
- **i+1 calculator**: table-driven tests covering the boundary
  thresholds (49%/50%, 84%/85%, etc.) and edge cases (no history yet).
- **Interleaving scheduler**: scenario tests, e.g. "user has mastered
  past-tense (accuracy ≥ 90%), weakest topic is phrasal verbs (accuracy
  40%) → phrasal-verb items should dominate the returned list."
- **Sample content**: a small hand-authored `SampleData` set (one
  mini package, a couple of units/lessons, ~15–20 items) used as
  fixtures across all of the above and as SwiftUI preview data later.

## Future slices (not in this spec)

1. LLM-based bulk content generation pipeline (produces real
   `ContentPackage` data at authoring time)
2. SwiftUI app shell — navigation, daily-loop UI, dashboard/analytics
3. Local on-device LLM integration — tutoring feedback, conversation
   practice
4. Speech/pronunciation pipeline — recording, speech-to-text, scoring
5. Subscriptions/monetization — StoreKit, package entitlements, ads
