# English Interface (L1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lexpath follows the device language — Turkish on Turkish devices, English everywhere else — including the AI tutor, chat and coach.

**Architecture:** English becomes the source language; every UI literal in `App/Sources` is rewritten in English and its current Turkish text becomes the `tr` translation in `Localizable.xcstrings` (edited only through `scripts/l10n.py`). `AppLanguage` decides the UI language once and is passed into TutorEngine requests as `LearnerLanguage`. A CI script compares compiler-extracted keys against the catalog.

**Tech Stack:** Swift 5.10, SwiftUI, String Catalogs, XcodeGen, GitHub Actions (macOS), Python 3 scripts.

**Spec:** `docs/superpowers/specs/2026-09-25-english-interface-design.md`

## Global Constraints

- This Windows machine has NO Swift toolchain. All Swift verification = push, then `gh run list --branch release-prep` (Swift Tests + App Build workflows). Never claim a Swift test passed without a green run.
- Python: use `C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe` (the WindowsApps alias silently virtualises writes).
- Never amend or force-push pushed commits. Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- The Turkish translation of each key MUST be the exact Turkish text the app shows today (a Turkish device must look identical).
- English copy: short, friendly, second person, sentence case; title-case only tab names. Brand name "Lexpath". Skill names: Vocabulary, Grammar, Reading, Listening, Writing, Speaking, Pronunciation. Rating buttons: Forgot · Hard · Knew it · Easy.
- Package JSON content (themes, titles, questions, explanations, package names) is data: never localized, never put in the catalog.
- `#Preview` sample data and comments may stay Turkish.

## Review Focus

1. Interpolated strings: the catalog key must match the compiler's key exactly (`%lld` for Int, `%@` for String, `%lf` Double) — a mismatch silently shows English to Turkish users. Covered by `check-localization.py` (Task 1).
2. Counts in English ("1 days") — every English key with a count gets `one`/`other` plural variations via `l10n.py --plural`.
3. Strings built outside SwiftUI views (view models, formatters, enums) must use `String(localized:)`, otherwise they are never extracted and stay English on Turkish devices. Covered by the check script only if extracted — so reviewers grep for plain `"…"` literals returned to UI.
4. `uppercased(with: Locale(identifier: "tr_TR"))` on English text → use `AppLanguage.current.locale`.
5. Existing tests asserting Turkish strings now see English on the CI simulator — update expectations, don't delete tests.

---

### Task 1: Localization infrastructure + pilot (RootTabView)

**Files:**
- Modify: `App/project.yml` (`developmentLanguage: en`)
- Modify: `App/Sources/EnglishApp/Resources/Localizable.xcstrings` (`sourceLanguage: en`)
- Create: `App/Sources/EnglishApp/AppLanguage.swift`
- Create: `scripts/l10n.py` (catalog editor), `scripts/check-localization.py` (CI guard)
- Modify: `.github/workflows/app-build.yml` (run the check after tests), `scripts/ci-app-build.sh` if it wraps xcodebuild
- Modify: `App/Sources/EnglishApp/RootTabView.swift` (pilot)
- Test: `App/Tests/EnglishAppTests/LocalizationTests.swift`

**Interfaces — Produces:**
- `enum AppLanguage { case turkish, english; static var current: AppLanguage; var locale: Locale }`
- `python scripts/l10n.py add "<English key>" "<Turkish>"` ; `python scripts/l10n.py add "%lld days" "%lld gün" --plural "%lld day"` (English `one` form; `other` = key) ; `python scripts/l10n.py list`
- `python scripts/check-localization.py <DerivedDataPath>` exit 1 on any extracted key missing a `tr` value.

Steps: implement AppLanguage (`Bundle.main.preferredLocalizations.first?.hasPrefix("tr")`), l10n.py (load/sort/write JSON with `ensure_ascii=False, indent=2`, `extractionState: "manual"`, `tr` stringUnit `state: translated`, plural variations under `en` localizations), check script (find `*.stringsdata` under DerivedData — JSON with `tables → Localizable → [{key}]` — compare keys; also fail if the catalog is not valid JSON), wire it into CI after xcodebuild test using the `-derivedDataPath` the workflow uses. Pilot: RootTabView tab titles → English + tr entries. LocalizationTests: load `Bundle(for: AppBundleToken)`/`Bundle.main` `tr.lproj` path and assert `NSLocalizedString("Today", bundle: tr, comment: "") == "Bugün"`; plural key check added in a later task once one exists. Push; both workflows green; the check step's log lists the pilot keys as present.

### Task 2: Language-aware TutorEngine

**Files:** `TutorEngine/Sources/TutorEngine/{TutorRequest,ChatRequest,CoachRequest,PromptBuilder,QuestionPromptBuilder}.swift`, new `LearnerLanguage.swift`, tests in `TutorEngine/Tests/TutorEngineTests/`.

**Produces:** `public enum LearnerLanguage: Sendable, Equatable { case turkish, english }`; each request type gets `public let learnerLanguage: LearnerLanguage` with init parameter `learnerLanguage: LearnerLanguage = .turkish` as the LAST parameter. `ChatPromptBuilder.systemInstructions(for:)`, `CoachPromptBuilder.systemInstructions(for:)` functions (keep the existing static `systemInstructions` constants as the Turkish values so existing tests compile).

Turkish prompts: byte-identical to today. English prompts:
- Tutor/question opening: "You are a concise, encouraging English tutor helping an English learner." — omit "Turkish translation:" line; question prompt labels the explanation "The explanation the app already showed (it may be in another language):"; anotherExample for question → "…as the correct answer." (no translation); add final line "Answer in English."
- Chat: "You are a concise, encouraging English tutor helping an English learner. Continue the conversation naturally, staying focused on English language learning."
- Coach system: "You are a warm, brief study coach for an English learner. Always write in English and address the learner as \"you\". Use only the information you are given; never invent numbers, dates or percentages. Write 2-4 short sentences; no lists or headings." User wrapper: "The learner's situation:\n<facts>\n\nDraft note:\n<draft>\n\nRewrite this draft in a more personal and encouraging way, keeping the same information."
Tests: one English-variant test per builder asserting the Turkish-specific phrases are absent and the English line present; all existing tests untouched and green.

### Task 3: Localize Today, Study, CoursePath, DesignSystem

Files: everything under `App/Sources/EnglishApp/{Today,Study,CoursePath,DesignSystem}/` plus their tests. Includes `RatingIntervalFormatter` (→ `String(localized: "\(days) days")` style keys with plurals: day/days, month/months, year/years; Turkish "gün/ay/yıl"), `SkillStyle`, `PlanTaskRow`, `Components`, and replacing `tr_TR` uppercasing with `AppLanguage.current.locale`. Update affected tests to English. Add a plural assertion to LocalizationTests (`"%lld days"` tr → `"%lld gün"`).

### Task 4: Localize Practice, LevelTest, Onboarding

Files: `App/Sources/EnglishApp/{Practice,LevelTest,Onboarding}/` + tests.

### Task 5: Localize Profile, Store, Tutor views, remaining App files

Files: `Profile/`, `Store/`, `Tutor/` views and view models, `AppModelContainer.swift`, `AppState.swift` and any other remaining file with a Turkish literal (`grep -rlE '"[^"]*[çğıöşüÇĞİÖŞÜ]' App/Sources`, excluding Coach/). Date formatting in ProfileView uses `AppLanguage.current.locale`.

### Task 6: Coach localization + wire LearnerLanguage into every AI request

Files: `Coach/` (templates, card, view model), `Tutor/TutorViewModel.swift`, `Tutor/ChatViewModel.swift`, practice tutor call site, coach note request. Every TutorEngine request built in the App passes `learnerLanguage: AppLanguage.current == .turkish ? .turkish : .english` (add `var learnerLanguage: LearnerLanguage` on AppLanguage). Coach templates via `String(localized:)`. Update coach tests to English.

### Task 7: Whole-branch review + close

- `grep -rnE '"[^"]*[çğıöşüÇĞİÖŞÜ][^"]*"' App/Sources --include=*.swift` → only `#Preview`/comment hits.
- Opus reviewer over the L1 range; one fix wave if needed; green CI.
- Update `docs/store-setup.md` TestFlight checklist (English device pass + Turkish device pass) and `Desktop/ENGLISH_KALANLAR.txt`.
