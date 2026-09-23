# Slice 9: AI Study Coach (Premium) — Design Spec

Date: 2026-09-24

## Context

Slices 6-8 built the goal engine, the full YDS package (version 8: 24 units,
148 lessons, 688 items, 701 questions) and StoreKit purchases with an AI
Premium subscription. The learner already enters an exam date during
onboarding (`LearnerProfile.examDate`), but nothing uses it: `DailyPlanBuilder`
plans each day from skill weights, daily minutes, due reviews and the next
accessible lessons, with no notion of a deadline or of falling behind.

The standing product direction names an AI study coach as the premium feature
that builds an automatic study programme for the goal and explains how the
learner should progress. This slice delivers it.

## Product decisions (user-approved, 2026-09-24)

1. **Coach = exam-date programme + narration.** A rule-based planner computes
   the programme from the exam date: target finish day, required pace,
   behind/ahead status, automatic catch-up, final review week. The on-device
   model only narrates it in short, personal Turkish. Numbers are never
   computed by the model.
2. **The coach really drives the daily plan.** For premium learners, the coach
   output is an extra input to `DailyPlanBuilder` (extra new-lesson budget
   when behind, priority skill, final-week review mode). For free learners the
   daily plan is byte-for-byte what it is today. One plan source; no separate
   roadmap screen.
3. **No exam date → ask, and fall back to free pace.** The coach card invites
   the learner to add a date; meanwhile the programme targets finishing the
   remaining accessible scope at the learner's daily minutes, and
   behind/catch-up logic still works.
4. **Approach: rules + model narration with a template fallback.** Every coach
   message exists as a deterministic Turkish template; the model text replaces
   it only when it is available and passes validation. The feature never
   breaks because the model is missing, slow or wrong.

## Non-goals

- A coach chat ("why this plan?") — the Tutor tab remains the chat.
- Narrowing scope ("skip these units") — the unreachable state only explains
  and links to the existing settings.
- Notifications/reminders, new tabs, new purchase products, server features.
- New persistent data or SwiftData schema changes.
- Model-generated plans or numbers.

## 1. Coach planner (LearningEngine, pure)

New `LearningEngine/Sources/LearningEngine/Planning/CoachPlanner.swift`. It
runs before `DailyPlanBuilder`, which it does not modify in behaviour for
absent input.

**Input (`CoachInput`):** `startOfToday`, optional `examDate`, `dailyMinutes`,
the path lessons (`[PlanLesson]`, which already carry `estimatedMinutes`,
`isAccessible`, `completedAt`), the count/minutes of locked lessons, the
per-skill minutes studied over the last 14 days (by day), skill weights.

**Rules:**
- `finalWeekDays = 7`. With an exam date, the **target finish day** for new
  lessons is `examDate - 7 days`; the last 7 days are review.
- **Remaining work** = sum of `estimatedMinutes` of accessible, not completed
  lessons. Locked lessons are excluded and reported separately.
- **Study days left** = whole calendar days from today (inclusive) to the
  target finish day (exclusive); calendar arithmetic as `StreakCalculator`
  (DST and month boundaries correct).
- **Required pace** = remaining work ÷ study days left (minutes/day of new
  lessons), rounded up to whole minutes.
- **New-lesson capacity** of a normal day = `dailyMinutes` minus the review
  share `DailyPlanBuilder` already reserves (at most 50%); the planner uses the
  same constant, exposed from `DailyPlanBuilder` rather than duplicated.
- **Status (`CoachStatus`):**
  - `noData` — no completed lesson and no study in the last 14 days.
  - `onTrack` — required pace ≤ capacity and the learner is not behind.
  - `behind(days: Int)` — lesson minutes completed in the last 14 days fall
    short of what the pace required over the same window; `days` = shortfall ÷
    required pace, rounded up.
  - `ahead(days: Int)` — the symmetric surplus, when ≥ 1 day.
  - `unreachable(shortfallMinutesPerDay: Int)` — required pace > the whole
    `dailyMinutes`.
  - `finalWeek` — today is within the last 7 days before the exam.
  - `examPassed` — exam date is today or earlier; the planner then behaves as
    free pace.
  - `scopeComplete` — no accessible lesson remains.
- **Status precedence** (first match wins): `scopeComplete`, `examPassed`,
  `finalWeek`, `noData`, `unreachable`, `behind`, `ahead`, `onTrack`.
  (`examPassed` then computes its numbers on free pace.)
- **Free pace (no exam date or exam passed):** target finish = today + ceil(
  remaining work ÷ capacity) days; behind/ahead are measured against capacity.
- **Output (`CoachPlan`):** status, target finish day, days to exam (optional),
  remaining minutes, completed share of accessible scope, locked lesson count,
  required minutes/day, and **`CoachDirective`** for the daily plan:
  - `extraLessonMinutes`: when behind, up to `dailyMinutes - capacity` extra
    new-lesson minutes (never above the whole `dailyMinutes`); otherwise 0.
  - `prioritySkill`: the weighted skill furthest behind its weekly target (as
    `DailyPlanBuilder` already computes); nil if none.
  - `reviewOnly`: true in `finalWeek` and `scopeComplete`.
- Recomputed from scratch every day; nothing is stored (same philosophy as the
  daily plan).

**`DailyPlanBuilder` change:** `DailyPlanInput` gains an optional
`coach: CoachDirective?` (default nil). When nil, output is identical to today.
When set: extra lesson minutes enlarge the lesson budget; the priority skill
wins ties in lesson selection; `reviewOnly` skips new lessons (the at-least-
one-lesson rule does not apply) and lets reviews use the whole day. Lesson
tasks added because of the extra budget carry `addedByCoach: true` (new field
on the lesson case's data, default false).

## 2. Coach note (narration)

- **`CoachBriefing`** (LearningEngine, pure): `CoachPlan` + last 7 days summary
  (days studied, lessons completed, weakest skill, streak).
- **`CoachMessageTemplates`** (LearningEngine, pure): one Turkish, informal
  ("sen") template per status (`onTrack`, `behind`, `ahead`, `finalWeek`,
  `unreachable`, `noExamDate`, `examPassed`, `scopeComplete`, `noData`),
  filled with the briefing's numbers. Deterministic; always available.
- **TutorEngine:** new `CoachRequest` (the briefing fields as plain values) and
  `CoachPromptBuilder`; the `TutorEngine` protocol gains
  `func respond(to coach: CoachRequest) async throws -> String`, implemented in
  `MLXTutorEngine` through the shared generate helper. The prompt passes the
  numbers and asks for 2-4 Turkish sentences, "sen" register, no new numbers.
- **Validation (`CoachNoteValidator`, TutorEngine, pure):** the model text is
  rejected, and the template shown, when it is empty, longer than 400
  characters, or contains a number (digits) that is not in the briefing.
  Timeout, thrown error, missing model and Simulator also fall back.
- **Cost:** generated at most once per day on first display, cached in memory
  for that day. The model is not loaded at launch because of the coach; the
  card shows the template immediately and swaps in the model note when ready,
  using the existing single-flight lazy load in `AppState`. Generation timeout
  = the existing Tutor timeout (30 s).

## 3. Screens and premium gate

- **Today screen — coach card at the top** (above the task cards):
  - Premium: coach note, a status badge ("Yoldasın" / "N gün geridesin" /
    "N gün öndesin" / "Son hafta: tekrar" / "Kapsam tamam"), and one progress
    line ("Sınava N gün · kapsamın %X'i bitti · günde ~Y dk yeni ders"). Coach-
    added lesson tasks show a "Koç ekledi" tag.
  - `unreachable`: explains the shortfall and offers "Günlük süreyi artır" and
    "Sınav tarihini değiştir", both opening the existing Profile settings.
  - No exam date: "Sınav tarihini ekle, programını kurayım" invitation opening
    the exam-date setting; free pace still runs underneath.
  - Locked scope: a line that the programme updates when the rest of the
    package is unlocked.
  - Free learner: a small locked teaser card ("AI Koç: sınav tarihine göre
    program") that opens the existing premium paywall. Their plan is unchanged.
- **Profile — "Koç" section (premium):** this week's days/minutes studied,
  lessons completed, skill balance, target finish date.
- **Gate:** `premiumProvider.isPremium`. Because the coach works without the
  model (templates), `TutorAccess.unavailable` does not hide it; only
  non-premium learners see the lock. No new product; AI Premium covers it. The
  paywall's feature list gains "Sınav tarihine göre kişisel program".
- Existing design system components, Turkish strings in the String Catalog,
  Dynamic Type and VoiceOver labels. Tabs unchanged.

## 4. Edge cases

- Exam date today or past → `examPassed` note ("sınav tarihin geçti, yeni bir
  tarih ekle"), free pace.
- Exam within 7 days → `finalWeek`, review only.
- All accessible lessons completed → `scopeComplete`, review only.
- First day / no history → `noData`, pace from remaining scope, no behind.
- Premium lapses → the plan immediately returns to free behaviour; no data
  lost.
- Model failures never surface as errors; the template is shown.

## Testing (all in CI)

- **LearningEngine:** `CoachPlanner` table tests for every status, exam-date
  and free-pace paths, locked scope, day boundaries (DST, month end), extra
  budget cap; `DailyPlanBuilder` regression proving identical output with
  `coach: nil`, plus tests for extra budget, priority skill tie-break,
  `reviewOnly`, `addedByCoach`; `CoachMessageTemplates` asserting concrete
  Turkish strings.
- **TutorEngine:** `CoachPromptBuilder` output; `CoachNoteValidator` accepts
  valid text and rejects empty, over-long and foreign-number text.
- **App:** coach card view model — premium vs free, model present/absent (fake
  engine), timeout and validation fallback, same-day cache; plan coordinator
  passes the directive only for premium.
- **Device (TestFlight checklist):** real model note quality in Turkish, card
  layout at large Dynamic Type, coach-added tasks on a behind schedule.

## Acceptance criteria

1. Free learner: daily plan identical to before (regression test green); a
   locked coach teaser opens the paywall.
2. Premium learner with an exam date: coach card shows correct status and pace;
   when behind, the plan contains coach-added lessons within `dailyMinutes`;
   in the final week, no new lessons.
3. Premium learner without an exam date: invitation + free-pace programme.
4. Without the model (Simulator/CI), every coach state renders its template.
5. No SwiftData schema change; both CI workflows green.
