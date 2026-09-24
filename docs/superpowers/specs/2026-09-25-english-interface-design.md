# L1 — English interface (Lexpath goes bilingual)

Date: 2026-09-25 · Status: approved (user delegated all decisions until TestFlight: "bana tekrar izin sorma")

## Why

Lexpath will be sold globally. Today every screen, the AI coach and the tutor
assume a Turkish-speaking YDS candidate. After this slice the app follows the
device language: Turkish devices see Turkish, every other device sees English.
This is sub-project L1 of four:

| # | Sub-project | Depends on |
|---|---|---|
| L1 | English interface + language-aware AI (this spec) | — |
| L2 | Multi-package infrastructure (package choice, per-package purchase, English-medium content format) | L1 |
| L3 | Business English package content | L2 |
| L4 | Everyday English package content | L2 |

## Decisions (user)

- Interface language follows the device: `tr` → Turkish, anything else → English.
- The YDS package content stays Turkish-medium (explanations, Turkish
  translations, grammar and strategy lessons). It is aimed at Turkish exam
  candidates; global users get value from L3/L4 packages.
- The AI (tutor, chat, coach) speaks the interface language.

## Design

### 1. Strings

- `developmentLanguage` becomes `en`; `Localizable.xcstrings` gets
  `sourceLanguage: en` and a `tr` translation for every key.
- Every user-visible literal in `App/Sources` is rewritten in English.
  SwiftUI literals (`Text("…")`, `Button("…")`, `Label`, `navigationTitle`,
  `.alert` titles, etc.) are localized automatically by key. Strings built
  outside views (view models, formatters, templates, enums such as
  `SkillStyle`) use `String(localized: "…")` so the compiler extracts them.
- Interpolated keys follow Apple's format: `Int` → `%lld`, `String` → `%@`.
  English keys that contain a count get `plural` variations (`one`/`other`)
  in the catalog; Turkish uses a single form.
- Content that comes from package JSON (unit themes, lesson titles, questions,
  explanations, package names) is data, not UI: shown verbatim, never put in
  the catalog.
- Hard-coded `Locale(identifier: "tr_TR")` (uppercasing, date formatting) is
  replaced by `AppLanguage.current.locale`, so Turkish dotted İ stays correct
  for Turkish and English uses English rules.

### 2. `AppLanguage`

A tiny enum in the App target:
`enum AppLanguage { case turkish, english }` with
`static var current` = `.turkish` when `Bundle.main.preferredLocalizations.first`
starts with `tr`, otherwise `.english`; plus `locale`. It is the single
source for "which language is the UI in" and is passed into the AI layer.

### 3. Language-aware AI (TutorEngine)

- New public `LearnerLanguage { turkish, english }` in TutorEngine.
- `TutorRequest`, `QuestionTutorRequest`, `ChatRequest` and `CoachRequest`
  gain `learnerLanguage` (default `.turkish` in the initialisers so existing
  call sites and tests keep compiling; the App always passes the real value).
- Prompt wording:
  - Tutor/question prompts: Turkish → unchanged ("Turkish-speaking learner
    preparing for the YDS exam", Turkish translation lines, "then translate it
    into Turkish"). English → "an English learner", no Turkish translation
    line, no translate-into-Turkish instruction, the Turkish explanation line is
    labelled as such and the tutor is told to answer in English.
  - Chat system prompt: English variant drops "Turkish-speaking".
  - Coach: Turkish system prompt unchanged; English variant is a direct
    English equivalent ("warm, brief study coach… always write in English…
    never invent numbers… 2–4 short sentences"). The user message wrapper is
    also bilingual. `CoachNoteValidator` is language-neutral already.
- Coach templates (`CoachMessageTemplates`) become localized strings, so the
  fallback text matches the interface language.

### 4. Guarding completeness (CI)

`scripts/check-localization.py`, run in the App Build workflow after the
build: reads the keys the compiler extracted (`*.stringsdata` in DerivedData)
and fails when any key is missing from `Localizable.xcstrings` or lacks a
non-empty `tr` value; also fails on catalog entries whose English plural
variations are malformed. A small XCTest loads the compiled `tr.lproj` bundle
and checks a few representative keys (a plain key, an interpolated key, a
plural key) resolve to Turkish.

### 5. Tests

Existing App tests that assert Turkish text are updated to the English source
text (the CI simulator runs in English). The Turkish side is covered by §4.
TutorEngine prompt tests gain English-variant cases; existing Turkish-variant
expectations stay unchanged.

## Out of scope

- Translating YDS package content; languages other than tr/en.
- Store metadata and screenshots (after L4).
- Per-package goal wording in prompts (L2 adds the package goal to the requests).

## Acceptance

- No Turkish literal remains in `App/Sources/**/*.swift` except sample data in
  `#Preview` blocks and comments (checked by grep in the final review).
- Check script + tr bundle test green in CI; all existing tests green.
- An English-device run shows English UI and English AI prompts; a Turkish
  device run is visually identical to today.
