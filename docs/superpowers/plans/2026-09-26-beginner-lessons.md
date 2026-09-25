# Beginner Lessons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Step-by-step bilingual lesson cards, Turkish explanations (with an English toggle) for every learner-facing explanation, package-specific naming and a one-time package intro.

**Architecture:** Per-lesson overlay files (`content/<pkg>/lessons/<lessonID>.json`) are merged by the assemblers into the package JSON (cards on the grammar item, bilingual question explanations, passage translations, word meanings). LearningEngine stores cards as JSON on `ItemContent` and decodes them into public Codable types; the App renders them and picks the language per block with a toggle.

**Tech Stack:** Swift 5.10, SwiftUI (iOS 17), SwiftData, Python content scripts, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-26-beginner-lessons-design.md`

## Global Constraints

- No local Swift: verify via CI (Swift Tests + App Build incl. translation check). Python: `C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe`.
- New UI strings via `scripts/l10n.py add`. SwiftData: additive optional properties only; IDs never change.
- Turkish explanations are authored, never machine-translated. English fields contain no Turkish characters.
- Card rules: one idea per card; `purpose` ≤ 2 short sentences with a Turkish comparison when one exists; exactly 3 examples, each ≤ 12 words; one `mistake`; one `check` question with 3 options; YDS may add `examTip`.
- Turkish UI: explanations default to Turkish with "İngilizcesini göster"; English UI: English only, no toggle.
- No TestFlight upload unless the user asks. Never amend/force-push.

## Review Focus

1. English-UI learner studying Business after Turkish meanings are added — no Turkish meaning/option appears anywhere (card, level test).
2. A grammar lesson whose overlay is missing (old install / partial content) — old explanation text still shows, lesson still works.
3. Package intro when the learner switches to a package they already saw — not shown again; Profile re-show works.
4. Toggle state when moving to the next question — each explanation opens in the default language, not a stale toggle.
5. Very long Turkish text at the largest Dynamic Type in cards — scrolls, nothing clipped.

---

### Task 1: LearningEngine — lesson cards, bilingual explanations, passage translation

**Files:** Create `LearningEngine/Sources/LearningEngine/Models/LessonCards.swift`; modify `Models/ItemContent.swift` (+`lessonCardsJSON: String? = nil`, computed `lessonCards: LessonCards?`), `Models/Question.swift` (+`explanationEN: String? = nil`, `explanationTRText: String? = nil`, `func explanation(for code: String) -> String`), `Models/Passage.swift` (+`bodyTR: String? = nil`), `Models/ContentPackage.swift` (+`introEN/introTR`, `func intro(for:) -> String?`), `Import/ContentDocuments.swift`, `Import/ContentImporter.swift`. Test `LearningEngine/Tests/LearningEngineTests/LessonCardsTests.swift`.

**Produces (public):**
```swift
public struct LessonCards: Codable, Equatable, Sendable {
    public struct PatternPart: Codable, Equatable, Sendable { public let text: String; public let role: String } // subject|verb|aux|object|other
    public struct Example: Codable, Equatable, Sendable { public let en: String; public let tr: String; public let highlight: String }
    public struct Mistake: Codable, Equatable, Sendable { public let wrong: String; public let right: String; public let note: LocalizedTextDocument }
    public struct Topic: Codable, Equatable, Sendable {
        public let title: LocalizedTextDocument; public let purpose: LocalizedTextDocument
        public let pattern: [PatternPart]; public let patternNote: LocalizedTextDocument?
        public let examples: [Example]; public let mistake: Mistake
    }
    public struct Check: Codable, Equatable, Sendable {
        public let prompt: String; public let options: [String]; public let correctIndex: Int; public let explanation: LocalizedTextDocument
    }
    public let topics: [Topic]; public let check: Check; public let examTip: LocalizedTextDocument?
}
extension LocalizedTextDocument { public func text(for code: String) -> String } // requested side, else the other, else ""
```
`LocalizedTextDocument` gains `Codable` + public memberwise init. Documents: `LearningItemDocument.lessonCards: LessonCards?`, `QuestionDocument.explanationLocalized: LocalizedTextDocument?`, `PassageDocument.bodyTR: String?`, `ContentPackageDocument.introLocalized: LocalizedTextDocument?`.

- [ ] Tests: cards round-trip through importer (item → `lessonCards` equal to document); `text(for:)` fallback both ways and empty; `Question.explanation(for:)` picks localized side else base `explanationTR`; passage `bodyTR` stored; intro stored; old JSON without any new field imports unchanged.
- [ ] Implement; push; Swift Tests green. Commit.

### Task 2: Content pipeline — lesson overlays, intro, package-specific names, golden example

**Files:** Create `scripts/overlay_lib.py`; modify `scripts/assemble-content.py`, `scripts/assemble-package.py`, `scripts/titles_lib.py` (intro), `content/*/titles.json` (+`"intro"`, YDS vocabulary renames), create `content/everyday-english-1/lessons/day-u01-grammar.json` (golden example below).

**Overlay format** (`content/<pkg>/lessons/<lessonID>.json`, all keys optional):
```json
{
  "lessonCards": { "topics": [ { "title": {"en","tr"}, "purpose": {"en","tr"}, "pattern": [{"text","role"}], "patternNote": {"en","tr"}, "examples": [{"en","tr","highlight"}], "mistake": {"wrong","right","note": {"en","tr"}} } ], "check": {"prompt","options","correctIndex","explanation": {"en","tr"}}, "examTip": {"en","tr"} },
  "questionExplanations": { "<questionID>": {"en": "...", "tr": "..."} },
  "passageTR": "…",
  "wordMeanings": { "<itemID>": "…" }
}
```
Merge rules: `lessonCards` → the lesson's grammarPoint item; `questionExplanations` → question `explanationLocalized`; `passageTR` → passage `bodyTR`; `wordMeanings` → item `translationTR`. Lint (`OverlayError`): unknown lesson/question/item id; card rules from Global Constraints (topics ≥1, pattern ≥2 parts, exactly 3 examples ≤12 words each, `highlight` substring of its example, check 3 options with valid index, every `{en,tr}` non-empty, no Turkish characters in `en`/`wrong`/`right`/examples' `en`/check prompt+options); `examTip` only in YDS; packages listed in `REQUIRE_COMPLETE` must have an overlay with cards for every grammar lesson, TR+EN explanations for every question and a meaning for every word (Business/Everyday) — list starts empty and each content wave adds its package.

Names: YDS vocabulary units → "Akademik kelimeler: Ekonomi" / "Academic words: Economy" (and Bilim ve araştırma / Science and research, Hukuk ve toplum / Law and society, Akademik yazım / Academic writing, Sağlık ve tıp / Health and medicine, Çevre ve enerji / Environment and energy, Teknoloji / Technology, Eğitim / Education, Tarih ve kültür / History and culture, Psikoloji / Psychology, Siyaset ve yönetim / Politics and government, Medya ve iletişim / Media and communication); their lessons "<unit> · N". YDS grammar units "YDS Gramer: …", exam units "YDS Soru tipleri: …", technique units "YDS Teknikleri: …". Lint: YDS titles never contain "Business"/"İş İngilizcesi"; Business/Everyday titles never contain "YDS".

Intro (`titles.json` `"intro": {"en","tr"}`), e.g. YDS tr: "YDS'de kelime, gramer, okuma ve çeviri soruları var; dinleme ve konuşma yok. Bu yüzden planın bu dört beceriye odaklanır ve sınav soru tiplerini tek tek çalıştırır."

Golden example (`day-u01-grammar.json`) — author exactly in this style:
```json
{
  "lessonCards": {
    "topics": [{
      "title": {"en": "Present simple for habits", "tr": "Alışkanlıklar için geniş zaman"},
      "purpose": {"en": "Use it for things you do regularly, like your daily routine.", "tr": "Düzenli yaptığın şeyler için kullanılır; Türkçedeki \"-r\" (gelirim, içerim) gibi."},
      "pattern": [{"text": "I / you / we / they", "role": "subject"}, {"text": "verb", "role": "verb"}, {"text": "he / she / it", "role": "subject"}, {"text": "verb + s", "role": "verb"}],
      "patternNote": {"en": "Add -s only after he, she and it.", "tr": "-s eki sadece he, she ve it'ten sonra gelir."},
      "examples": [
        {"en": "I drink coffee every morning.", "tr": "Her sabah kahve içerim.", "highlight": "drink"},
        {"en": "She works in a bank.", "tr": "Bir bankada çalışır.", "highlight": "works"},
        {"en": "We usually walk to school.", "tr": "Genellikle okula yürürüz.", "highlight": "walk"}
      ],
      "mistake": {"wrong": "He work every day.", "right": "He works every day.", "note": {"en": "He, she, it: add -s.", "tr": "He, she, it varsa fiile -s ekle."}}
    }],
    "check": {"prompt": "My sister ---- tea every evening.", "options": ["drink", "drinks", "drinking"], "correctIndex": 1,
      "explanation": {"en": "\"My sister\" is she, so the verb takes -s: drinks.", "tr": "\"My sister\" = she; bu yüzden fiile -s gelir: drinks."}}
  }
}
```
- [ ] Python self-test (`scripts/test_overlays.py`): golden example merges; each lint rule rejects a crafted bad overlay.
- [ ] Regenerate resources (YDS version 11, Business/Everyday 3); update version assertions; push; CI green. Commit.

### Task 3: App — cards screen, language toggle, Turkish explanations

**Files:** Create `App/Sources/EnglishApp/Practice/LessonCardsView.swift`, `App/Sources/EnglishApp/DesignSystem/BilingualText.swift`; modify `Practice/PracticeSessionViewModel.swift` (Step `.cards(LessonCards)` preferred over `.explanation`; `QuestionVM` + `explanationEN: String?`, `explanationTRText: String?`; `PassageVM` + `bodyTR: String?`), `Practice/PracticeSessionView.swift`, `Practice/PracticeQuestionView.swift` (explanation block + toggle; passage "Türkçesini göster"), `Study/StudyCardView.swift` (meaning row only on Turkish UI), `LevelTest/LevelTestViewModel.swift`/`LevelTestCandidateFetcher` (meaning = Turkish UI && translation non-empty ? translation : definition). Tests in `PracticeSessionViewModelTests`, `LevelTestViewModelTests`, new `BilingualTextTests`.

**Produces:** `enum BilingualPick { static func text(en: String?, tr: String?, base: String, language: AppLanguage, showEnglish: Bool) -> String }` (Turkish UI + !showEnglish → tr ?? base; otherwise en ?? base) and `static func offersToggle(en:tr:language:) -> Bool` (Turkish UI and both sides non-empty and different).

- [ ] Tests: pick matrix; toggle offered only on Turkish UI with both sides; VM chooses `.cards` when present and `.explanation` otherwise (Review Focus 2); level-test options use definitions on English UI even when translations exist (Review Focus 1); toggle resets per question (Review Focus 4, VM exposes `explanationShowsEnglish` reset in `next()`).
- [ ] LessonCardsView: `TabView(.page)` — per topic: page 1 title + purpose + colored pattern (+ note), page 2 examples (English, Turkish below, highlight bold primary), page 3 mistake (❌/✅ + note); then examTip page (YDS), then check page (answer → feedback → "Go to questions"); toggle button in the top bar on Turkish UI; ScrollView per page (Review Focus 5).
- [ ] Strings TR; push; CI green. Commit.

### Task 4: App — one-time package intro

**Files:** Create `App/Sources/EnglishApp/Onboarding/PackageIntroView.swift`, `App/Sources/EnglishApp/Onboarding/PackageIntroFacts.swift`; modify `RootTabView.swift` (sheet when the active package's intro not seen, after onboarding), `Profile/ProfileView.swift` ("Show package intro again"). Tests `PackageIntroTests`.

**Produces:** `struct PackageIntroFacts { let focusSkills: [Skill]; let skippedSkills: [Skill]; let units: Int; let lessons: Int; let dailyMinutes: Int; let estimatedWeeks: Int; init(package: ContentPackage, dailyMinutes: Int) }` (estimatedWeeks = ceil(total lesson minutes / (dailyMinutes × 0.6) / 7), min 1 — 60% of daily time goes to new lessons, the rest to reviews); `enum PackageIntroStore { static func hasSeen(_ id: String, defaults:) -> Bool; static func markSeen(_ id: String, defaults:) }`.

- [ ] Tests: facts from a test package (focus = weight > 0 sorted desc, skipped = weight 0); estimate arithmetic; seen once per package; switching to a seen package does not re-show (Review Focus 3).
- [ ] Pages per spec §2 with strings TR; push; CI green. Commit.

### Task 5: Content wave — Everyday English

For each unit (8): overlays for the grammar lesson (cards), practice/grammar question explanations (TR + existing EN), passage translation, and all word meanings of its three vocabulary lessons. Authored by one subagent per two units following the golden example and Global Constraints; each pair reviewed by a fresh reviewer (Turkish naturalness, correctness of TR meanings, beginner level, card rules). Then add `everyday-english-1` to `REQUIRE_COMPLETE`, regenerate, CI green, commit per pair.

### Task 6: Content wave — Business English

Same as Task 5 for `business-english-1`.

### Task 7: Content wave — YDS lesson cards

Cards for all 50 YDS grammarPoint lessons (30 grammar, 2 practice, 18 technique): Turkish-first, beginner-friendly, `examTip` carries the exam trap that used to crowd the explanation; the YDS "Tenses" lesson splits into one topic per tense. Question explanations stay as they are. Batches of ~8 lessons per subagent + fresh reviewer; add `yds-academic-vocab-1` to `REQUIRE_COMPLETE`; CI green.

### Task 8: Close

Whole-branch review (fresh, most capable model) + one fix pass; screenshots workflow updated to capture a card lesson (TR + EN), a Turkish answer explanation and the intro pages; refreshed PNGs to `Desktop/Lexpath ekran görüntüleri`; update `docs/store-setup.md` device checks and `Desktop/ENGLISH_KALANLAR.txt`. No TestFlight upload.
