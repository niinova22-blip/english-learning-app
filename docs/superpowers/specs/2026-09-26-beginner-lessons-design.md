# Beginner-friendly lessons, Turkish explanations, package intros

Date: 2026-09-26 · Status: approved in conversation (sections 1-3)
Branch: `release-prep`. No TestFlight upload unless the user asks.

## Why

Build 2 feedback: the learner may start from zero and does not read English.
Today (1) YDS vocabulary units are named "Business & Economics" etc. and read
like the Business English package; (2) nothing explains how the study plan
works (free vs AI Premium) when a package starts; (3) grammar explanations are
dense walls of text (YDS "Tenses" covers four tenses, jargon, exam traps in one
screen); (4) Business and Everyday explanations, answer explanations and word
meanings are English-only, so a Turkish learner cannot follow them.

Research basis: explicit rule explanation outperforms implicit exposure for
grammar; L1 (Turkish) explanation and L1-L2 contrast help beginners; cognitive
load theory — one idea at a time and worked examples first for novices
(Ellis, Instructed SLA review; SSLA "L1 explicit instruction…"; Sweller/CLT).

## Decisions (user-approved)

- Turkish explanations are **authored** (not machine-translated).
- Explanation format: **step-by-step lesson cards**.
- Package intro, package-specific naming, App Store Connect steps as below.

## 1. Package-specific naming

- YDS unit themes and lesson titles get YDS-specific wording in both
  languages via `content/yds-academic-vocab-1/titles.json`:
  vocabulary "Akademik kelimeler: Ekonomi" / "Academic words: Economy" (and so
  on per topic, lessons "… · 1"), grammar "YDS Gramer: …", exam units
  "YDS Soru tipleri: …", technique units "YDS Teknikleri: …".
- Business titles prefixed/phrased as business ("İş İngilizcesi: Toplantılar"),
  Everyday as daily life ("Günlük hayat: Yemek"). No title in one package may
  name another package's domain as its category.
- IDs unchanged → progress kept. Lint: no duplicate display titles across packages.

## 2. One-time package intro

- Shown once per package, the first time it becomes the active goal (after
  onboarding or after "Change goal"), in the UI language; 4 swipeable pages:
  1. What this package prepares you for (package-specific text from content,
     bilingual `introLocalized`).
  2. Free plan daily routine: reviews first (spaced repetition — each word
     returns just before you'd forget it), then new lessons; skill mix shown
     with the package's real weights (why: e.g. YDS has no pronunciation);
     first unit free.
  3. With AI Premium: coach plans by exam/target date, adds catch-up lessons
     when behind, final week reviews only; tutor explains any word/question.
  4. How we'll progress: units in order on the Course tab, minutes per lesson,
     estimated finish at the learner's daily minutes.
- Numbers from data (weights, unit/lesson counts, daily minutes).
- Seen state per package ID in UserDefaults; Profile → "Show package intro again".

## 3. Lesson cards

- Grammar items gain an optional structured `lessonCards` object (bilingual):
  `purpose {en,tr}` (with L1 contrast), `pattern` (English formula as ordered
  parts, each `{text, role}` for coloring), `patternNote {en,tr}`,
  `examples [{en, tr, highlight}]` (exactly 3, short),
  `mistake {wrong, right, note {en,tr}}`,
  `check {prompt, options[], correctIndex, explanation {en,tr}}`,
  optional `examTip {en,tr}` (YDS only).
- The lesson screen shows cards one idea per card (swipe), then the practice.
  Old `explanationTR` stays as fallback for installs without cards.
- Topics that are too big are split into several grammar items/cards (e.g.
  YDS Tenses → one card set per tense) without changing lesson IDs.
- Scope: all 50 YDS grammar points and all 16 Business/Everyday grammar points.

## 4. Turkish explanations and the language toggle

- Business & Everyday: fill `translationTR` for all 480 words; answer
  explanations become bilingual (`explanationLocalized {en,tr}` on questions);
  passages gain `bodyTR` (translation).
- Turkish UI: cards, answer explanations and meanings default to Turkish, each
  block has "İngilizcesini göster ↔ Türkçesini göster"; passages open in
  English with "Türkçesini göster". English UI: English only, no toggle.
- YDS: answer explanations already Turkish; unchanged this round.
- Level test: options use the Turkish meaning on Turkish UI and the English
  definition on English UI (not "translation if non-empty").
- Tutor prompts keep working (Turkish translation line now present for
  Business/Everyday on Turkish UI; English UI unaffected).

## 5. App Store Connect (browser, parallel to code)

Rename to Lexpath + subtitles (EN "English for YDS, Work & Travel",
TR "YDS, iş ve günlük İngilizce"; if the name is taken, report and propose —
do not decide alone); prices (US base + Turkey override) for the five products;
1-week free introductory offer on both subscriptions; product display
names/descriptions EN+TR; Beta App Information with the contact the user gave.
No App Review submission.

## Order

ASC in parallel → naming + intro → card infrastructure (proven end to end on one
lesson) → content waves Everyday → Business → YDS grammar, each unit reviewed
independently → whole-branch review + one fix pass → refreshed screenshots on
the Desktop (card lesson, Turkish explanation, intro pages).

## Error handling

Missing Turkish/English side → the other side, never empty. Missing cards →
old explanation text. Intro content missing → generic pages without the
package paragraph.

## Testing

Unit: language pick + toggle state; intro once per package and re-show;
level-test option language; no cross-package category names; card decoding
and fallback. Lint: both languages on every bilingual block, no Turkish
characters in English fields, card completeness (pattern, 3 examples, mistake,
check). CI green. Screenshots refreshed.

## Out of scope

Simplifying the ~700 YDS answer explanations; audio; new packages.
