# Slice 7a: Practice Lessons Infrastructure — Design Spec

Date: 2026-09-19

## Context

Slices 6a/6b shipped the goal engine, daily plan, onboarding, level test and
the Ders Yolu tab. Only vocabulary lessons have a lesson screen today:
`PlanTaskAction.action(for:)` returns `.comingSoon` for every other lesson
skill, and the item bank contains 120 vocabulary items only.

Slice 7 (YDS full curriculum) was decomposed on 2026-09-19 into:

- **7a (this spec):** lesson-type infrastructure with a small but real sample
  of content per lesson type.
- 7b: YDS grammar curriculum. 7c: YDS reading + exam question types.
  7d: vocabulary expansion + study techniques.

7a must make 7b-7d "content work only": new topics/passages/question sets are
JSON, not code.

## Product decisions (user-approved)

1. **Review model: topic-level.** One FSRS card per grammar topic / practice
   set, not per question. A due card re-serves a fresh selection of questions
   from that lesson's pool.
2. **Grammar lesson flow: explain, then ask.** Short Turkish explanation card,
   then 5-8 YDS-style questions with immediate per-answer feedback and a Turkish
   explanation. (Exam-mode with deferred feedback is a possible later feature.)
3. **Tutor from questions: yes.** An "Öğretmene Sor" button on the feedback
   card, seeded with question, options and the learner's answer; hidden when
   the on-device tutor is unavailable.
4. **Sample content: small but real.** 2 grammar topics (Tenses, Conditionals;
   each explanation + 6-8 questions), 2 reading passages (5 questions each),
   1 cloze set, 1 sentence-completion set, 1 translation set; about 60-70
   questions, real YDS quality, shipped in the app.
5. **Architecture: shared question model + one generic practice screen**
   (rejected: per-type models/screens; questions embedded as JSON blobs).

## Scope

In scope: `Question`, `Passage`, `QuestionAttempt` models; `practiceSet` item
type and `ItemContent.explanationTR`; content JSON v3 + importer validation;
sample content; score-to-rating mapping; question selection; a new
"practice review" plan task; `PracticeSessionViewModel` and screens; tutor
question-context request; routing from Bugün / Ders Yolu; Turkish strings.

Out of scope: the curriculum itself (7b-7d); listening/writing/speaking/
pronunciation lessons; timed mock-exam mode; option shuffling (options keep
content order); tap-to-translate in passages; user-editable weights.

## Data model

New SwiftData models (registered in `AppModelContainer.schema`):

- `Question`: `id` (unique, stable), `prompt`, `options: [String]` (exactly 5),
  `correctIndex` (0-4), `explanationTR`, `kind`
  (`grammar | reading | cloze | sentenceCompletion | translation`), `order`.
  Relationships: `lesson: Lesson?`, `passage: Passage?`.
- `Passage`: `id` (unique), `title`, `body`; owns its questions.
- `QuestionAttempt`: `userID`, `questionID`, `wasCorrect`, `answeredAt`,
  `selectedIndex`.

Changes to existing models (additive, defaulted, lightweight-migration-safe):

- `ItemContent.explanationTR: String?` (default nil): the grammar topic
  explanation (rule, examples, common traps), Turkish.
- `LearningItemType` gains `practiceSet`. A grammar topic is a
  `LearningItem(.grammarPoint)`; every non-grammar, non-vocabulary lesson owns
  exactly one `LearningItem(.practiceSet)` as its FSRS card.
- Skill attribution for these items comes from the owning lesson's `skill`
  (so a reading set counts toward `reading`), not from the item type alone.
  `Skill.forItemType` stays as the fallback.

## Spaced repetition

- One FSRS card per grammar topic / practice set (existing `UserItemState`).
- On session completion the score maps to an FSRS rating:
  `< 50%` Again, `50-74%` Hard, `75-99%` Good, `100%` Easy.
  (Boundaries: exactly 50% is Hard, exactly 75% is Good.) The rating is applied
  only when the session completes.
- When a card is due, the session serves a selection from the lesson's pool
  (size = min(pool, 8 for grammar / 5 for others)) in this priority: never
  attempted, then most recently answered wrong, then attempted-correctly,
  least recently attempted first. Selection is deterministic given an injected
  RNG for tie-breaks.
- Known limitation, accepted: a reading passage has 5 questions, so a review
  re-serves the same questions until 7c grows the pool.

## Content format

- Package `version` becomes 3. Lesson JSON gains `questions: [...]` and, for
  reading lessons, a `passage: {id, title, body}` that each of its questions
  references. Grammar lessons gain the topic `explanationTR`.
- Importer validation (each rejected case has its own error and test): option
  count != 5; `correctIndex` out of range; empty `explanationTR`; duplicate
  question id (across the package); a lesson with a practice skill but no
  questions; a reading question referencing a missing passage.
- Update path is unchanged from 6a: validate into a temporary in-memory store
  first, then replace the installed content, so bad content cannot delete the
  old. Item and question ids are stable so history is preserved.

## Planning and routing

- `DailyPlanBuilder` gains a task kind `practiceReview(itemID, title, skill,
  minutes: 3)` for due practice cards. At most 2 per day, placed after the
  vocabulary review task, within the existing daily-time budget rules. The
  vocabulary review task is unchanged.
- `PlanTaskAction`: lessons with any skill that has content route to
  `.startLesson(id:)`; practice reviews route to a practice-review start.
  `.comingSoon` remains only for skills with no content.
- Access policy is unchanged: lessons outside the free preview stay locked
  ("Paketi aç").

## Screens and flow

One `PracticeSessionView` for all types, driven by `PracticeSessionViewModel`.

1. Grammar lesson: explanation card first, then "Sorulara geç".
2. Reading lesson: the passage stays pinned in a collapsible panel above the
   question.
3. Question step: progress bar "3/8", prompt, options A-E; tapping an option
   commits the answer immediately.
4. Feedback: correct option green, a wrong pick red, each with icon and text
   (never color alone); Turkish explanation card; "Sonraki".
5. "Öğretmene Sor" on the feedback card only when the tutor is available
   (`AppState.isTutorAvailable`); opens the existing sheet with a question
   context (prompt, options, learner's answer). `TutorEngine` gains a
   question-context request and prompt builder with tests.
6. Summary: correct count and percentage, list of missed questions, "Bu konuyu
   N gün sonra tekrar edeceğiz", "Plana dön".

Recording rules: every answer is saved as a `QuestionAttempt` immediately. The
lesson is marked complete (`LessonProgress`) and the FSRS rating applied only
when the summary is reached. Quitting mid-way leaves the lesson incomplete;
reopening starts from the beginning; earlier attempts still influence
selection.

Design rules: existing design system (paper background, serif titles, skill
colors, dark mode), Dynamic Type, Reduce Motion, VoiceOver labels like
"A şıkkı: …", all copy in Turkish via the String Catalog.

## Error handling

- Malformed content: rejected by validation above; installed content untouched.
- Pool smaller than the selection size: ask all questions.
- Save failure (attempt, progress or FSRS update): the screen stays open with a
  Turkish error row and "Tekrar dene"; no half-complete "lesson done" state.
- Locked lesson: unchanged, shown as "Paketi aç".
- Tutor unavailable: the button is not shown.
- Existing installs: new fields are optional/defaulted and new models are new
  entities (lightweight migration); real-device migration is verified at
  TestFlight because this machine has no Swift toolchain.

## Testing

All verification runs in CI (no Swift toolchain locally).

- LearningEngine (pure logic): score to rating including the 50/75/100
  boundaries; question selection priority and determinism; the new
  `DailyPlanBuilder` task (cap of 2, ordering, budget); each importer
  validation rule (one test per rejection).
- App: `PracticeSessionViewModel` (answer, feedback, summary, save failure,
  quit mid-way, small pool), `PlanTaskAction` routing, a test that the real
  shipped content file passes the importer, and tutor question-context prompt
  tests.
- Known gap: screens cannot be run or viewed in CI (no UI tests); covered by
  code review and TestFlight on device.

## Task order (refined in the plan)

1. Models, item type, JSON schema, importer validation.
2. Sample content (7 lessons, ~60-70 questions), package version 3, plus an
   independent content review.
3. Score-to-rating mapping and question selection (pure).
4. `DailyPlanBuilder` practice-review task and `PlanTaskAction` routing.
5. `PracticeSessionViewModel`.
6. Practice screens (explanation, question, feedback, summary).
7. Tutor question context and screen integration.
8. Wiring in Bugün / Ders Yolu, residue cleanup.
