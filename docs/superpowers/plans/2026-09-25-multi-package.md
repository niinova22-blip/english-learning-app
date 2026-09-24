# Multi-package Infrastructure (L2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lexpath installs, sells and switches between several goal packages (YDS, Business English, Everyday English), including English-medium content without Turkish translations.

**Architecture:** Optional `audience`/`summary` on the package document and model; the app seeds every bundled package independently; one shared `PackageOrdering` feeds onboarding and a new goal switcher; `LearningGoal.isExam` switches exam/target wording; level test and tutor fall back to English definitions when a translation is empty.

**Tech Stack:** Swift 5.10, SwiftData, SwiftUI, StoreKit 2, Python content scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-25-multi-package-design.md` (and L1 spec for localization rules).

## Global Constraints

- No local Swift: verify via CI on push (Swift Tests + App Build incl. "Check Turkish translations").
- Every new UI string: English in code + Turkish via `scripts/l10n.py` (L1 rules, `.superpowers/sdd/2026-09-25-english-interface/localize-brief.md`).
- SwiftData changes must be additive optional properties (lightweight migration).
- YDS package: item/lesson/unit IDs unchanged; Turkish prompts for YDS byte-identical.
- Python: `C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe`. Never amend/force-push.

## Review Focus

1. Upgrading an installed app: YDS re-import with the new `audience` field must keep progress (IDs stable) — covered by existing seeder tests + version bump test.
2. A package whose JSON resource is missing or broken must not stop the others from seeding.
3. Switching goal mid-day: Today plan/Coach must immediately use the new package; lessons of the old package keep their LessonProgress.
4. Empty `translationTR`: no blank "Turkish:" rows on cards, no empty options in the level test, no "Turkish translation: " line in prompts.
5. Non-exam goals never show "exam" wording (onboarding, settings, profile, coach).

---

### Task 1: LearningEngine — package metadata, isExam, level-test meaning
Files: `LearningEngine/Sources/LearningEngine/Models/ContentPackage.swift` (+`audience: String?`, `summary: String?`, `LearningGoal.isExam`), `Import/ContentDocuments.swift` (+optional fields), `Import/ContentImporter.swift` (copy them), `Planning/LevelTestEngine.swift` (`LevelTestCandidate.translationTR` → `meaning`), tests in `LearningEngine/Tests/LearningEngineTests/` (importer reads audience/summary and tolerates absence; isExam table; level test uses `meaning`). App call site `App/Sources/EnglishApp/LevelTest/LevelTestViewModel.swift`: `meaning: content.translationTR.isEmpty ? content.definition : content.translationTR`.

### Task 2: Bundled packages + YDS metadata + store products + CI content check
- `App/Sources/EnglishApp/BundledPackages.swift`: `enum BundledPackages { static let resourceNames = ["YDSAcademicVocabulary1", "BusinessEnglish1", "EverydayEnglish1"] }`; `AppModelContainer.seedRealContentIfNeeded` loops, skipping missing resources, collecting errors without aborting (error surfaced as today only if YDS fails or nothing is installed).
- YDS: `scripts/assemble-content.py` stamps `audience: "tr"` and a Turkish `summary` ("YDS'ye hazırlık: akademik kelimeler, gramer, okuma ve sınav soru tipleri."), `PACKAGE_VERSION` 9; regenerate outputs.
- `App/StoreKit/Products.storekit`: add non-consumables `…package.business`, `…package.everyday` (reference names "Business English", "Everyday English", same price tier as YDS). `docs/store-setup.md`: product table rows.
- `.github/workflows/swift-tests.yml` (where assemble-content drift is checked): add `python3 scripts/assemble-package.py --all --check`.
- Tests: seeding two packages side by side; missing resource skipped (inject resource list).

### Task 3: Package ordering, onboarding picker, goal switcher, card
- `App/Sources/EnglishApp/Access/PackageOrdering.swift`: `static func sorted(_ packages: [ContentPackage], for language: AppLanguage) -> [ContentPackage]` + `static func showsTurkishSpeakersNote(_ p: ContentPackage, language: AppLanguage) -> Bool`.
- Onboarding goal step uses it and shows `summary` + level + "For Turkish speakers" caption.
- `Profile/GoalSwitcherSheet.swift` + `GoalSwitcherViewModel` (select → set `activePackageID`, save); Profile MY GOAL row gets "Change goal".
- Study card hides the translation row when empty.
- Tests: ordering tr/en; switcher keeps both packages' LessonProgress and updates the profile.

### Task 4: Exam vs target wording + AI goal text
- Onboarding date step, StudySettingsSheet, ProfileView, CoachMessageTemplates, coach badges: when `!goal.isExam` use "target date"/"hedef tarih" variants (new catalog keys).
- TutorEngine: `TutorRequest`/`QuestionTutorRequest` gain `goalDescription: String?` (default nil → current wording); prompt builders: Turkish + nil → unchanged; otherwise opening "... helping a Turkish-speaking learner who is <goalDescription>." / "... helping an English learner who is <goalDescription>."; omit "Turkish translation:" when empty. App passes: yds → nil, business → "improving their business English", conversational → "improving their everyday English", toefl → "preparing for the TOEFL exam".
- Tests in TutorEngine for goal text and empty translation; App coach template tests for target wording.

### Task 5: Close
Whole-branch review of L2, fix wave, green CI, update `Desktop/ENGLISH_KALANLAR.txt`.
