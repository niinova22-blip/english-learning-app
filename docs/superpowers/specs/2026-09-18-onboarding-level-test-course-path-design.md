# Slice 6b: Onboarding, Level Test & Course Path — Design Spec

Date: 2026-09-18

## Context

Slice 6a shipped the design system, the goal engine (`LearnerProfile`,
`SkillWeights`, `LessonAccessPolicy`, `LessonProgress`, `DailyPlanBuilder`)
and the redesigned Bugün/Tutor/Profil screens. `TodayPlanCoordinator`
currently bootstraps a `LearnerProfile` silently on first launch, with
defaults (20 min/day, no exam date) and no user input.

This slice adds the missing front door: a first-run onboarding flow that
collects the learner's goal, exam date and daily study time, offers a
short adaptive level check, and a new "Ders Yolu" tab that shows the
learner's full course path instead of just today's tasks.

This was brainstormed as part of the broader roadmap (A+B → C → D → E)
approved 2026-09-14; most product-level decisions (level test is skippable,
5-8 minutes, CEFR estimate, onboarding collects goal/exam date/daily
duration) were made in that earlier session. This spec resolves the
remaining technical unknowns found while implementing: the content-package
system currently has exactly one installed package (YDS), and the item
bank has no grammar content yet, so the level test is vocabulary-only for
now, and the goal-selection step is built to support multiple packages
even though only one exists today.

## Scope

In scope:
- Onboarding flow: goal selection (from installed `ContentPackage`s),
  exam date, daily study minutes, level test (skippable), result screen.
- Adaptive level test: vocabulary-only multiple-choice quiz drawing on the
  active package's existing `LearningItem`s, producing a CEFR estimate.
- "Ders Yolu" tab: full course path (all units/lessons of the active
  package) with lock/progress state, reusing existing lesson-start
  mechanics.

Out of scope (explicitly deferred):
- Grammar/reading questions in the level test (no such content exists
  yet; the test engine is written to support additional item types later
  without a redesign).
- Using the level test result to seed FSRS state / skip "already known"
  words — the result is informational only (CEFR badge + vocabulary score
  in Profil).
- Retroactive onboarding for existing installs with a `LearnerProfile`
  already present — no real users exist yet, so a fresh onboarding on
  next launch for current dev/TestFlight installs is acceptable.

## Data model changes (LearningEngine)

- `LearnerProfile` gains two fields:
  - `onboardingCompletedAt: Date?` — nil means onboarding is not done;
    `RootTabView` gates on this.
  - `hasSkippedLevelTest: Bool` (default `false`) — tracked separately
    from `onboardingCompletedAt` so Profil can offer "seviye testini şimdi
    yap" to someone who skipped it without conflating that with an
    incomplete onboarding.
- New `@Model` `LevelTestResult`: `userID` (unique per user — at most one
  result is kept; retaking overwrites it), `cefrLevel: String` (one of
  `A2`, `B1`, `B2`, `C1`), `vocabularyScore: Double` (0-1, fraction
  correct), `completedAt: Date`.
- No new model for goal selection — the existing `ContentPackage` list is
  the source of options; onboarding writes the chosen id to
  `LearnerProfile.activePackageID`.
- `AppModelContainer.schema` gains `LevelTestResult` (same "no real users
  yet, migration unverified on-device but accepted" caveat as Slice 6a).

## Onboarding flow

- New `Onboarding/` feature folder (matching the existing
  Today/Tutor/Profile/Study pattern): `OnboardingFlowView` (container) +
  `OnboardingViewModel` (state machine).
- States: `.goalSelection → .examDate → .dailyDuration → .levelTestIntro
  → .levelTest → .levelTestResult → .done`. Back navigation is allowed
  between steps; a progress indicator (e.g. "2/6") is shown.
- `.levelTestIntro` offers "Başla" and "Atla" (skip). Skipping sets
  `hasSkippedLevelTest = true` and jumps straight to `.done` without
  creating a `LevelTestResult`.
- All choices are held in `OnboardingViewModel` state and only written to
  SwiftData once, at `.done` (`onboardingCompletedAt`, `activePackageID`,
  `dailyMinutes`, `examDate`, and the `LevelTestResult` if the test was
  taken). If the user quits mid-flow, nothing is persisted and onboarding
  restarts from `.goalSelection` on next launch.
- `RootTabView` checks `appState`'s derived `hasCompletedOnboarding`
  (from `LearnerProfile.onboardingCompletedAt`). When false, it shows
  `OnboardingFlowView` as the app's root content instead of the
  `TabView` — not a sheet/modal.
- Startup ordering: content seeding (`ContentSeeder`) must complete
  before the onboarding gate is evaluated, since goal selection and the
  level test both read installed `ContentPackage`s/`LearningItem`s.

## Level test engine (LearningEngine)

- `LevelTestEngine`: a pure, deterministic component (testable without
  SwiftUI) that runs a 12-question adaptive staircase over the active
  package's `vocabulary`-type `LearningItem`s, using their existing
  `baseDifficulty` (observed range in the YDS package: 0.15-0.6, skewed
  low — see caveat below).
- Algorithm: first question at the item bank's median difficulty
  (~0.3). A correct answer moves the next question's target difficulty
  up; an incorrect answer moves it down. Step size shrinks every 3
  questions for coarse-to-fine convergence. No item repeats within one
  test administration.
- Each question: the headword plus 4 choices (1 correct `translationTR`,
  3 drawn from other items' `translationTR`, chosen without regard to
  difficulty — the word bank's 120 entries span distinct enough domains
  that a careful synonym-avoidance step isn't needed).
- Scoring: `vocabularyScore` = fraction correct; the difficulty level
  reached by the end of the staircase maps to one of 4 fixed CEFR bands
  (A2/B1/B2/C1) via fixed thresholds over the observed 0.15-0.6 range.
- **Caveat surfaced during design, shown to the user in Profil as a
  one-line disclaimer**: because the item bank is a single curated
  academic-vocabulary list (not a general-language item bank), the CEFR
  estimate is an approximation of "how much of this YDS word list you
  already know", not a rigorous general placement test.
- The test does not write `UserItemState` or otherwise touch FSRS
  scheduling — it is a self-contained quiz, isolated from the study/review
  path.
- Extensibility: the engine takes a list of candidate items and doesn't
  assume `vocabulary` type, so grammar questions can be added later
  (Slice 7+) by including `grammarPoint` items in the candidate pool once
  such content exists — no redesign needed then.

## "Ders Yolu" tab

- New `CoursePath/` feature folder: `CoursePathView` + `CoursePathViewModel`.
- `RootTabView` gains a 4th tab, ordered Bugün · Ders Yolu · Tutor ·
  Profil (Tutor stays conditional on `isTutorAvailable` as today).
- Data: active package's `Unit`s ordered by `order`, each with its
  `Lesson`s ordered by `order`, grouped under a section header (`theme`).
- Per-lesson status, derived from existing models (no new logic):
  completed (`LessonProgress.completedAt` set), accessible-not-started
  (`LessonAccessPolicy` says accessible), or locked (not accessible).
  Rendered with the existing `SkillBadge`/`ProgressBar` components.
- Tap behavior reuses `PlanTaskAction` exactly as Bugün does today:
  vocabulary lesson → `startLesson(id:)` opens `StudySessionView`; other
  skills → `comingSoon`; locked → "Paketi aç" prompt. No new study flow.
- Ders Yolu and the Bugün plan are independent views over the same
  underlying data (`Unit`/`Lesson`/`LessonProgress`) — Bugün is "what to
  do today", Ders Yolu is "the whole map".

## Testing approach

- `LevelTestEngine`: unit tests on fixed fixtures — correct answers raise
  the next difficulty, incorrect answers lower it, no repeats across 12
  questions, CEFR bucketing at threshold boundaries.
- `OnboardingViewModel`: unit tests on the state machine — forward/back
  transitions, skip behavior, that nothing is persisted before `.done`.
- `CoursePathViewModel`: unit tests that lessons are grouped/ordered
  correctly and that status (locked/accessible/completed) matches
  `LessonAccessPolicy`/`LessonProgress`, following the same test patterns
  already used for those two types in Slice 6a.
- Views are not unit tested; App Build CI (Xcode build + existing UI
  smoke tests) is the verification gate for them, same as every prior
  slice.
- As with all Swift work on this machine: verified only via CI
  (`scripts/ci-test.sh`, `scripts/ci-app-build.sh`), never locally — no
  Swift toolchain is installed here.
