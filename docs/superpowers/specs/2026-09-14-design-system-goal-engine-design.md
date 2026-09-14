# Slice 6a — Design System + Goal Engine (Design Spec)

Date: 2026-09-14
Status: Approved in brainstorming (all 4 design sections), pending written-spec review
Visual references: `.superpowers/brainstorm/233-1789413122/content/` (`visual-style.html` option C, `home-structure.html` option A, `screens-6a.html`) — git-ignored mockups, kept on disk.

## Context and product direction

The app is moving from a single flashcard queue to **goal-based study packages** (YDS, Business English, Travel, TOEFL, …), each a followable course that fully prepares the learner for that goal. Packages will be sold individually; a separate premium subscription unlocks AI features; an AI study coach will generate and explain study programmes later. Each goal weights the skills it trains (e.g. YDS has no pronunciation section, so pronunciation weight is 0).

This work was decomposed into sub-projects, built in this approved order:

| Slice | Scope |
|---|---|
| **6a (this spec)** | Design system + goal engine + redesigned Today / study card / summary / Tutor / Profile screens |
| 6b | Onboarding (goal, exam date, daily minutes), adaptive placement test, Course Path tab |
| 7 | Content: full YDS curriculum (vocabulary, grammar, reading, cloze, exam question types, techniques); later TOEFL / Business / Travel |
| 8 | StoreKit 2: per-package purchases + AI premium, entitlements, paywall |
| 9 | AI study coach (premium) |

Speech/pronunciation work comes after these and must read the goal's skill weights.

The current UI is default SwiftUI (plain `Text`/`.bordered` buttons, mixed English/Turkish copy) and does not meet the project's quality bar.

## Decisions (user-approved)

1. **One active goal.** A learner may own several packages, but exactly one active package drives the daily plan and skill weights. It is switchable; progress is kept per package.
2. **Shared 7-skill set** for every goal: `vocabulary`, `grammar`, `reading`, `listening`, `writing`, `speaking`, `pronunciation`. Each package supplies its own weights. Exam-specific question types (YDS cloze, sentence completion, translation) are *content* under these skills (Slice 7), not engine concepts.
3. **Access = entitlement interface + free preview.** A package is either `owned` or `preview`. In preview only the lessons of the package's first unit (lowest `order`) are accessible; the rest are shown locked. 6a ships a development implementation (toggle "Tüm paketleri aç (geliştirici)", default off = preview); Slice 8 replaces its internals with StoreKit without touching screens.
4. **Weights live in content data**, not code. Adding a package is content work only.
5. **Visual direction C — "academic and focused"**: warm paper background, serif headings, petrol-green primary, orange secondary.
6. **Home = daily plan first** (option A). Tabs in 6a: **Bugün · Tutor · Profil** (Course Path tab arrives in 6b).
7. **Rating labels**: `Bilemedim · Zorlandım · Bildim · Çok kolay` (the user did not understand Again/Hard/Good/Easy), each showing its next-review interval, plus a one-time explanatory hint.
8. **Level placement** is a short adaptive test — **6b**, not 6a.
9. Entire UI in **Turkish**.

## Non-goals for 6a

- Onboarding, placement test, exam date entry, Course Path tab (6b).
- Grammar/reading/listening lesson screens (Slice 7, arrive with that content).
- Real purchases (Slice 8); AI coach and exam-date pacing (Slice 9).
- User-editable skill weights.
- Measuring real study time (estimates only).
- Any server component — everything stays on device.

## 1. Data model and content format

### 1.1 Skill and weights (LearningEngine)

```swift
public enum Skill: String, Codable, CaseIterable, Sendable {
    case vocabulary, grammar, reading, listening, writing, speaking, pronunciation
}

public struct SkillWeights: Codable, Sendable, Equatable {
    public let values: [Skill: Double]   // all 7 present, each >= 0, sum > 0
    public func share(of skill: Skill) -> Double  // normalized
    public var activeSkills: [Skill]     // weight > 0, in Skill.allCases order
}
```

Mapping from item type to skill (used for review minutes): `vocabulary`, `phrase`, `collocation` → `.vocabulary`; `grammarPoint` → `.grammar`.

### 1.2 Package document changes

`ContentPackageDocument` gains:

```json
"version": 2,
"skillWeights": { "vocabulary": 35, "grammar": 30, "reading": 35,
                  "listening": 0, "writing": 0, "speaking": 0, "pronunciation": 0 }
```

`LessonDocument` gains `"title": String` and `"skill": String` (a `Skill` raw value).

`skillWeights` is decoded from the JSON object as `[String: Double]` and converted to `SkillWeights` by the importer (a `[Skill: Double]` dictionary would otherwise encode/decode as a flat array). `SkillWeights` gets an explicit `Codable` implementation that uses the same keyed-object form, so its SwiftData storage and the content file share one representation. An unknown key in `skillWeights` is rejected like a missing one.

The importer rejects a package (throws `ContentImportError`, nothing inserted) when: any of the 7 skills is missing from `skillWeights`, any weight is negative, the weights sum to 0, `version < 1`, or a lesson's `skill` is not a valid `Skill`.

SwiftData: `ContentPackage` gains `version: Int` and `skillWeights: SkillWeights`; `Lesson` gains `title: String` and `skill: Skill`.

The existing YDS package (`App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`, 4 units × 3 lessons) is updated to `version: 2`, the weights above, `"skill": "vocabulary"` on all 12 lessons, and titles of the form `"<Unit theme> · <lesson order>"` (e.g. `"Science & Research Methods · 2"`). `scripts/assemble-content.py`, its batch sources, the CI drift check, and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json` are updated to match; the script validates the new fields with the same rules as the importer.

### 1.3 Learner-side models (new SwiftData models, LearningEngine)

- `LearnerProfile` — `userID` (unique), `activePackageID: String`, `dailyMinutes: Int` (default 20), `examDate: Date?` (nil in 6a), `createdAt: Date`.
- `LessonProgress` — `id = "\(userID)|\(lessonID)"` (unique), `userID`, `lessonID`, `startedAt: Date`, `completedAt: Date?`.

Streak is **not stored**; it is derived (see §2.5).

Both models are added to `AppModelContainer.schema`.

### 1.4 Content versioning

On launch, `AppModelContainer` seeding becomes:
- no package with the bundled package's `id` → import it;
- stored `version` < bundled `version` → replace: delete the stored package (cascade removes its units/lessons/items/contents), import the bundled one, and save once. On any error, `context.rollback()` so the old content remains, and record the error in the existing `containerCreationError` channel (surfaced in Profile).

User state (`UserItemState`, `ReviewLog`, `LessonProgress`) is keyed by stable string IDs and is untouched by replacement. Progress rows for lessons/items that no longer exist are ignored by all readers. Implementation must verify in a CI test that delete-then-insert of the same unique IDs within one save works in SwiftData; if it does not, save the delete first and re-import in a second save, keeping the rollback-on-import-failure guarantee by importing into a validated in-memory document before deleting.

### 1.5 Access

LearningEngine (pure, testable):

```swift
public enum PackageAccessLevel: Sendable { case owned, preview }

public struct LessonAccessPolicy: Sendable {
    /// owned → every lesson; preview → only lessons of the unit with the lowest `order`.
    public func isAccessible(lesson: LessonRef, in package: PackageOutline, level: PackageAccessLevel) -> Bool
}
```

(`LessonRef` / `PackageOutline` are plain value snapshots of the SwiftData graph so the policy and the plan builder never touch SwiftData.)

App:

```swift
protocol PackageAccessProvider {
    func accessLevel(forPackageID id: String) -> PackageAccessLevel
}
struct DevelopmentPackageAccessProvider: PackageAccessProvider   // reads UserDefaults "dev.unlockAllPackages"
```

Injected through `AppState`, so Slice 8 swaps the implementation only.

## 2. Daily plan builder (LearningEngine)

A pure `DailyPlanBuilder`: no SwiftData, no clock reads — every input is passed in, so the same inputs always yield the same plan.

### 2.1 Inputs

```swift
struct DailyPlanInput {
    let weights: SkillWeights
    let dailyMinutes: Int
    let lessonsInPathOrder: [PlanLesson]   // all lessons of the active package, ordered by (unit.order, lesson.order)
                                           // PlanLesson: id, title, skill, estimatedMinutes, isAccessible,
                                           //             completedAt: Date?, itemCount
    let dueNowCount: Int                   // UserItemState with dueDate <= now
    let reviewedTodayCount: Int            // distinct items with a ReviewLog today (local calendar day)
    let pastWeekSkillMinutes: [Skill: Double] // the 7 local days BEFORE today
    let startOfToday: Date
}
```

Constants: `minutesPerReviewCard = 0.4`, `maxReviewShareOfBudget = 0.5`.

### 2.2 Algorithm

1. **Review task.** `reviewCap = floor(dailyMinutes * 0.5 / 0.4)`. `target = min(reviewedTodayCount + dueNowCount, reviewCap)`. If `target > 0`, emit `.review(cardCount: target, minutes: target * 0.4, isDone: reviewedTodayCount >= target || dueNowCount == 0)`. Review minutes count toward the `.vocabulary`/`.grammar` skills by item type when computing history (§2.4), and toward the day's budget here.
2. **Lesson selection.** Candidates = lessons that are accessible and **not completed before `startOfToday`** (lessons completed today stay in the plan, marked done), whose skill is in `weights.activeSkills`. Each skill offers only its next candidate in path order. Repeatedly pick the skill with the largest deficit:
   `deficit(s) = share(s) * (pastTotal + plannedTotal) - (pastMinutes[s] + plannedMinutes[s])`,
   breaking ties by larger weight, then `Skill.allCases` order. Add that lesson; stop when the remaining budget (`dailyMinutes - plannedTotal`) is ≤ 0 or no candidates remain.
3. **At least one lesson.** If step 2 added nothing because the review task consumed the budget, but a candidate exists, add the single top-deficit lesson anyway.
4. **Zero weight / missing content.** Skills with weight 0 are never selected. Skills with no candidate lessons are skipped; their share is effectively redistributed because deficits are only compared among skills that have candidates.
5. **Preview exhausted.** If no accessible, uncompleted lesson remains in the package but an inaccessible one does, append `.locked(lessonID, title)` for the first inaccessible lesson in path order.
6. **Order.** Review task first, then lessons in selection order, then the locked card.

Stability rule: lesson choice reads only history before `startOfToday` and completion state before `startOfToday`, so the plan does not reshuffle during the day; only `isDone` flags change.

### 2.3 Output

```swift
struct DailyPlan: Equatable {
    let tasks: [PlanTask]   // .review(cardCount:minutes:isDone:) | .lesson(id:title:skill:minutes:isDone:) | .locked(id:title:)
    let totalMinutes: Double
    let weeklyBalance: [SkillBalance]  // for activeSkills: target share vs actual share over the past 7 days
}
```

If `tasks` is empty (or only contains done tasks), Today shows the "Bugünlük hepsi bu" completion state.

### 2.4 History (App coordinator)

`pastWeekSkillMinutes` = for the 7 local days before today: completed lessons' `estimatedMinutes` under the lesson's skill, plus `ReviewLog` count × 0.4 under the reviewed item's type-mapped skill.

### 2.5 Streak (LearningEngine, pure)

`StreakCalculator.streak(activityDays: Set<DateComponents>, today:)` counts consecutive local days ending today that have at least one review or completed lesson. If today has no activity yet, counting starts from yesterday (the streak is not broken until today ends).

### 2.6 Executing tasks

- **Review task** → `StudySessionView` over due cards: `DailySessionBuilder` with candidates restricted to items that already have a `UserItemState` (never-seen items are introduced only by lessons), up to the review task's card count. The old "backfill never-seen items" logic in `TodaySessionCoordinator` is removed.
- **Vocabulary lesson** → `StudySessionView` over the lesson's items in order, skipping items that already have a `UserItemState`. Creates `LessonProgress` (`startedAt`) on first entry. Each rating goes through the existing `FSRSStateStore.recordReview`. When every item of the lesson has a `UserItemState`, set `completedAt`. Leaving with ✕ keeps saved ratings; re-entering resumes at the first unrated item.
- **Non-vocabulary lesson** in 6a (none exist yet) → shown in the plan but its Start button opens a "Bu ders türü yakında" placeholder. The builder may select it; the content is expected in Slice 7.
- **Locked task** → tapping shows a sheet: "Bu ders paketin tam sürümünde" with the lesson title (the purchase flow arrives in Slice 8).

## 3. Screens and design system (App)

### 3.1 Design system — `App/Sources/EnglishApp/DesignSystem/`

- **Colors** (light / dark, dynamic `UIColor` in code, same roles in both):
  paper `#FBF8F2` / `#151A1C`; surface `#FFFFFF` / `#1E2527`; border `#E7E1D6` / `#2E3739`; ink `#1F2A2E` / `#EEF2F1`; secondary ink `#6B7280` / `#9CA3AF`; primary `#0F766E` / `#2DD4BF`; accent `#EA580C` / `#FB923C`; danger `#B91C1C` / `#F87171`.
  Skill colors: vocabulary = primary, grammar = accent, reading `#3B82F6`, listening `#7C3AED`, writing `#0891B2`, speaking `#DB2777`, pronunciation `#65A30D`.
- **Typography**: titles `.system(..., design: .serif)` (New York; no bundled fonts), body SF; Dynamic Type only (no fixed point sizes).
- **Components**: `PaperCard`, `PrimaryButton`, `SkillBadge`, `ProgressBar`, `RatingButton` (label + interval), `PlanTaskRow` (review / lesson / locked / done states), `StreakBadge`, `StatTile`. Each has SwiftUI `#Preview`s in light and dark.
- **Motion**: card flip = 3D `rotation3DEffect`, replaced by a cross-fade when Reduce Motion is on; `.sensoryFeedback` on rating and on task completion.

### 3.2 Screens

Tabs: **Bugün · Tutor · Profil**. The Tutor tab keeps its existing show-only-when-`isTutorAvailable` rule.

1. **Bugün** (`TodayPlanView`, replaces `TodayView`): package label + streak, serif title "Bugünün planı", "N görev · yaklaşık M dk", `PlanTaskRow` list (done rows struck through; the first undone task highlighted with "Başla"; locked row with "Paketi aç"), and a weekly skill-balance section for active skills. States: loading, "İçerik yüklenemedi", "Bugünlük hepsi bu". The plan recomputes on appear and when the scene becomes active (covers midnight).
2. **StudySessionView** (card front): ✕ close, `ProgressBar` + "3/10", context line ("YENİ DERS · <title>" or "TEKRAR"), headword card, "Cevabı göster" (tapping the card also flips).
3. **Card back**: headword, Turkish translation, definition, first example sentence, collocations (the field already exists in content but was never shown), a Tutor button (only when `isTutorAvailable`; opens the existing `TutorSheetView`, restyled), and the four `RatingButton`s. Intervals come from running `FSRSScheduler` for each rating on the item's current card state without persisting, formatted as "1 dk", "6 dk", "3 sa", "1 gün", "4 gün", "2 ay". One-time hint (UserDefaults `hint.ratingExplained`): "Kelimeyi ne kadar iyi bildiğini seç. Uygulama bir sonraki tekrar zamanını buna göre ayarlar."
4. **SessionSummaryView** (redesigned): "Ders tamamlandı" or "Tekrar tamamlandı", title, stat tiles (cards, % rated Bildim or Çok kolay, streak), "Tekrar etmen gerekenler" (items rated Bilemedim), "Plana dön".
5. **ProfileView** (replaces `SettingsView`): Hedefim (active package, access level, daily minutes — read-only in 6a), İstatistik (streak, words with state, completed/total lessons), Geliştirici (the "Tüm paketleri aç" toggle, the existing reset flow), storage warning section (existing), version.

Tutor chat and sheet adopt the colors and components; their behaviour is unchanged.

### 3.3 Language

All user-facing strings are Turkish. Strings go through a `Localizable.xcstrings` String Catalog with Turkish as the development language (`options.developmentLanguage: tr` in `project.yml`), so an English UI can be added later without code changes. Learning content itself (headwords, definitions, examples) stays English.

## 4. Error handling

| Situation | Behaviour |
|---|---|
| Invalid package (weights/skill/version) | Import throws, nothing inserted; existing content remains; message in Profile's storage warning |
| Version upgrade fails mid-way | `rollback()`; old content remains; message in Profile |
| No package at all | Today shows "İçerik yüklenemedi" |
| No `LearnerProfile` / active package missing | Create/repair the profile with the first package as active |
| Plan empty or all done | "Bugünlük hepsi bu" completion state |
| App open across midnight | Plan recomputed when the scene becomes active |
| Leaving a lesson with ✕ | Ratings kept; lesson not completed; resumes at first unrated item |
| Rating save fails | Existing behaviour: alert, stay on the same card, retry possible |
| Orphaned progress rows after a content update | Ignored |

## 5. Testing (all via CI — no local Swift toolchain)

**LearningEngine (`scripts/ci-test.sh`)**
- `Skill`/`SkillWeights` decoding, normalization, and each rejection rule.
- Importer: new fields; rejection cases insert nothing; version replacement preserves `UserItemState`/`ReviewLog`/`LessonProgress`; the delete-then-insert unique-ID behaviour (§1.4).
- `DailyPlanBuilder` table tests: review cap at 50% of budget; deficit-based skill choice; weight-0 skill never chosen; skill without lessons skipped; at least one lesson when the budget is consumed by reviews; locked card when the preview is exhausted; lessons completed today stay in the plan as done; identical inputs → identical plan; empty plan.
- `LessonAccessPolicy`: preview = first unit only; owned = all.
- `StreakCalculator`: gaps, today without activity, month/DST boundaries.

**App (`scripts/ci-app-build.sh`)**
- `TodayPlanCoordinator`: builds `DailyPlanInput` from SwiftData correctly (history window, due counts, access).
- Lesson session: creates `LessonProgress`, sets `completedAt` when all items are rated, resumes correctly.
- Profile repair fallback.
- Existing `TodaySessionCoordinatorTests` updated to the new review-only candidate rule.

**Content**: `assemble-content.py` validates the new fields; the CI drift check is updated.

**Accepted gap**: appearance, animation, and dark mode cannot be verified automatically (no Xcode or Simulator here; CI produces no screenshots). Every component and screen has light/dark `#Preview`s; visual verification happens on a Mac or via TestFlight.

## 6. Files (expected)

LearningEngine: `Models/Skill.swift`, `Models/LearnerProfile.swift`, `Models/LessonProgress.swift`, changes to `Models/ContentPackage.swift`, `Models/Lesson.swift`, `Import/ContentDocuments.swift`, `Import/ContentImporter.swift`; new `Planning/DailyPlanBuilder.swift`, `Planning/LessonAccessPolicy.swift`, `Planning/StreakCalculator.swift`; tests for each.

App: `DesignSystem/*`, `Today/TodayPlanView.swift`, `Today/TodayPlanCoordinator.swift`, `Study/StudySessionView.swift`, `Study/StudySessionViewModel.swift`, `Today/SessionSummaryView.swift` (rewritten), `Profile/ProfileView.swift` (replaces `Settings/SettingsView.swift`), `Access/PackageAccessProvider.swift`, `AppModelContainer.swift` (versioned seeding), `RootTabView.swift`, `Resources/Localizable.xcstrings`, `Resources/YDSAcademicVocabulary1.json`, `project.yml`; restyled `Tutor/TutorChatView.swift`, `Tutor/TutorSheetView.swift`; removal of `Today/TodayView.swift`.
