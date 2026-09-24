# L2 — Multi-package infrastructure

Date: 2026-09-25 · Status: approved (user delegated all decisions until TestFlight)
Depends on: L1 (English interface). Enables: L3 Business English, L4 Everyday English.

## Why

Lexpath ships three goal packages: YDS (Turkish-medium, for Turkish exam
candidates), Business English and Everyday English (English-medium, for
everyone). Today the app assumes exactly one bundled package, a Turkish
translation on every word, and an exam at the end of every goal.

## Decisions

1. **Content format (backward compatible).**
   - Package JSON gains optional `audience` (`"tr"` = written for Turkish
     speakers; absent = everyone) and optional `summary` (one sentence shown
     in the package picker, written in the package's medium language).
     `ContentPackage` gets `audience: String?` and `summary: String?`
     (optional → lightweight SwiftData migration).
   - `translationTR` may be `""` in English-medium packages. `definition`,
     `explanationTR` (field name kept; holds the explanation in the package's
     medium language) and all questions are English there.
   - YDS JSON gets `"audience": "tr"` and a Turkish `summary`; package version
     bumps so installed apps re-import (item IDs unchanged → history kept).
2. **Bundled packages.** `AppModelContainer` seeds every JSON listed in
   `BundledPackages.resourceNames` (`YDSAcademicVocabulary1`,
   `BusinessEnglish1`, `EverydayEnglish1`) independently via the existing
   `ContentSeeder.seed`; one bad file never blocks the others; a missing
   resource is skipped (so L2 can ship before L3/L4 content exists).
3. **Package picker order and labels.** Shared `PackageOrdering.sorted(_:for:)`:
   packages whose `audience` matches the UI language come first, then
   audience-free packages, then the rest; ties by name. Packages with
   `audience == "tr"` show a "For Turkish speakers" caption on English UI.
   Used by onboarding and the new goal switcher.
4. **Switching goal.** Profile → MY GOAL gets "Change goal": a sheet listing
   installed packages (same ordering, with level range, summary and a
   lock/owned badge). Choosing one sets `LearnerProfile.activePackageID`;
   Today, Course and Coach already derive from it. Progress is keyed by
   item/lesson IDs, so each package keeps its own progress. The exam/target
   date stays on the profile (one date); the level-test retake runs on the
   active package.
5. **Exam vs goal wording.** `LearningGoal.isExam` (`yds`, `toefl` → true).
   For non-exam goals the UI and coach say "target date"/"hedef tarih"
   instead of "exam date"/"sınav tarihi" (onboarding, settings, profile,
   coach templates and badges). Behaviour is identical.
6. **Level test for English-medium packages.** `LevelTestCandidate.translationTR`
   becomes `meaning`: the Turkish translation when non-empty, otherwise the
   item's English definition. Options are drawn from the same field.
7. **Cards.** The study card hides the translation row when `translationTR`
   is empty. Practice UI already shows `explanationTR` verbatim.
8. **AI.** Tutor requests (card, question) gain `goal: LearningGoal`-derived
   text (`goalDescription`): YDS → the existing wording (Turkish prompt stays
   byte-identical for YDS); business → "improving their business English";
   conversational → "improving their everyday English". The "Turkish
   translation:" line is omitted when the translation is empty. Coach facts
   use exam/target wording per §5.
9. **Store.** Product IDs `com.niinova22.englishapp.package.business` and
   `com.niinova22.englishapp.package.everyday` (non-consumable, like YDS);
   `App/StoreKit/Products.storekit` and `docs/store-setup.md` updated. The
   first unit of every package is the free preview (existing policy).
10. **Content pipeline.** `scripts/assemble-content.py` gains a package table
    so each package is authored under `content/<package-id>/` and assembled
    into `App/Sources/EnglishApp/Resources/<Resource>.json`; the CI drift
    check covers all packages. A lint rule: English-medium packages must not
    contain Turkish characters in `definition`/`explanationTR`/questions.

## Testing

- Seeder: two packages seed side by side; a broken second file leaves the
  first installed; a missing resource is skipped.
- `PackageOrdering` for tr/en UI; `isExam`; level-test `meaning` fallback;
  prompt builders (goal text, empty translation line omitted, YDS unchanged).
- Goal switcher view model: switching updates `activePackageID` and keeps
  LessonProgress of both packages.
- Localization check (L1) covers all new strings.

## Out of scope

Per-package exam dates, bundles/discounts across packages, speaking/listening features.
