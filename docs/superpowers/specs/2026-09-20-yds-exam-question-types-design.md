# Slice 7c: YDS Reading and Exam Question Types — Design Spec

Date: 2026-09-20

## Context

Slice 7a shipped the practice-lesson infrastructure with a small sample of each
YDS question type (2 reading passages, 1 cloze, 1 sentence completion, 1
translation). Slice 7b shipped the grammar curriculum (5 locked units, 30
lessons, 272 questions). The package is now 9 units, 49 lessons, 157 items and
335 questions at version 6.

The standing product direction says buying a package must fully prepare the
learner for the exam. YDS is 80 multiple-choice questions across a fixed set of
question types. 7c fills in the exam-type lessons that 7a only sampled, plus the
four YDS types the app does not model yet. Slice 7d (vocabulary expansion and
study techniques) and Slice 9 (AI study coach) follow.

7c is content work on top of the 7a infrastructure. The only code changes are
four new question-kind labels, a package version bump and the content lint.

## Product decisions (user-approved, 2026-09-20)

1. **All YDS exam types get real lessons:** reading comprehension, cloze,
   sentence completion, translation in both directions, paragraph completion,
   irrelevant sentence, dialogue completion and restatement.
2. **Four new question kinds** — `paragraphCompletion`, `irrelevantSentence`,
   `dialogueCompletion`, `restatement` — all fit the existing five-option
   question shape, so no new screen or importer logic is needed.
3. **Four new locked units** at orders 9-12; the free preview stays exactly the
   first unit.
4. **Same quality bar as 7b:** one defensible answer, refutable distractors,
   Turkish explanations that name at least two distractors, key-distribution
   lint, and an independent cold review of every unit before it counts.
5. **Original text only.** Every passage, dialogue and sentence is written for
   this app; no ÖSYM or other copyrighted exam material.
6. **Strategy cards ("how to solve this type") are Slice 7d.** 7c lessons use
   the existing `practiceSet` card, which by rule carries no explanation, and
   open straight into the questions; each question carries its own Turkish
   explanation.

## Non-goals

- New screens, new question UI, new importer logic beyond accepting the new kinds.
- Vocabulary expansion, study-technique lessons (Slice 7d), the AI coach (Slice 9).
- Listening or speaking content; TOEFL, Business or Travel packages.
- Changing the free preview, the access policy or the purchase flow.

## Units and lessons

All 33 lessons below are new; the counts are contractual.

| order | unit id | theme | lessons | questions |
|---|---|---|---|---|
| 9 | `yds-exam-unit-reading` | `Okuma anlama` | 8 reading | 40 |
| 10 | `yds-exam-unit-cloze-sentence` | `Cloze ve cümle tamamlama` | 4 cloze + 4 sentence | 72 |
| 11 | `yds-exam-unit-paragraph` | `Paragraf soruları` | 3 paragraph completion + 3 irrelevant sentence + 2 dialogue | 64 |
| 12 | `yds-exam-unit-translation-restatement` | `Çeviri ve yeniden ifade` | 3 EN→TR + 3 TR→EN + 3 restatement | 72 |

Totals: **33 lessons, 248 questions**, 12 passages (8 reading + 4 cloze).

### Lesson shapes (exact, enforced by the lint)

| type (id segment) | kind | skill | passage | questions | minutes |
|---|---|---|---|---|---|
| `reading` | `reading` | reading | yes | 5 | 10 |
| `cloze` | `cloze` | reading | yes | 8 | 10 |
| `sentence` | `sentenceCompletion` | grammar | no | 10 | 9 |
| `paragraph` | `paragraphCompletion` | reading | no | 8 | 10 |
| `irrelevant` | `irrelevantSentence` | reading | no | 8 | 9 |
| `dialogue` | `dialogueCompletion` | grammar | no | 8 | 8 |
| `translation-en-tr` | `translation` | reading | no | 8 | 9 |
| `translation-tr-en` | `translation` | reading | no | 8 | 9 |
| `restatement` | `restatement` | reading | no | 8 | 9 |

### Naming contract

- Lesson id `yds-exam-<type>-<n>` (`n` from 1); card id `yds-exam-card-<type>-<n>`;
  question id `<lesson id>-q<NN>` with `order = NN - 1`; passage id
  `yds-exam-passage-<type>-<n>` (reading and cloze only).
- Every lesson owns exactly one `practiceSet` item and no `explanationTR` on it
  (the existing 7a rule). Card fields follow the 7a practice cards: `headword`
  (English label), `frequencyRank` (unique, 3000 and up), `baseDifficulty`,
  `definition` (one Turkish line), `exampleSentences: []`, `translationTR` (the
  Turkish lesson title), `collocations: []`.
- Files: `content/yds-academic-vocab-1/exam/<unit-slug>/<type>-<n>.json`, one
  lesson document per file, without an `order` key; position in the unit table
  assigns it.

### Question conventions per type

- **reading:** stem is a question or a sentence ending in `----`; every
  question has `passageID` set to the lesson's passage. Passages are 180-260
  words, B2-C1 academic prose, and cover a spread of domains (economics,
  environment, health, technology, education, history of science, urbanism,
  law, psychology, energy).
- **cloze:** the passage carries blanks `(1)----` … `(8)----`; question `k`'s
  stem is the sentence with `(k) ----`; options are words or short phrases
  (connectors, prepositions, relatives, verb forms, vocabulary).
- **sentence:** one `----` at the end or middle of a sentence; options are
  clause completions.
- **paragraph:** a short paragraph (3-4 sentences) with one `----` where a
  sentence is missing; the options are five candidate sentences.
- **irrelevant:** five numbered sentences `(I)` … `(V)` in the stem; the
  options are exactly `I`, `II`, `III`, `IV`, `V`; the key is the sentence that
  breaks the paragraph's unity.
- **dialogue:** a two-speaker exchange with one `----`; options are candidate
  lines.
- **translation:** EN→TR stems are English sentences with Turkish options;
  TR→EN stems are Turkish sentences with English options.
- **restatement:** a stem sentence; the options are five sentences, exactly one
  of which preserves its meaning.

## Code changes

- `QuestionKind` gains `paragraphCompletion`, `irrelevantSentence`,
  `dialogueCompletion`, `restatement`. Nothing switches on the kind, so no
  screen changes; the importer already maps kinds through `QuestionKind(rawValue:)`
  and rejects unknown ones.
- `scripts/assemble-content.py`: the allowed-kinds set gains the four kinds; a
  new `EXAM_UNITS` table (like `GRAMMAR_UNITS`) loads the exam lesson files and
  appends the four units at orders 9-12; a lint keyed on the `yds-exam-` id
  prefix enforces the lesson-shape table, the naming contract, the per-type
  conventions above (cloze blank markers, the irrelevant-sentence options and
  numerals, exactly one `----` for sentence/paragraph/dialogue) and the existing
  key-distribution rule. `PACKAGE_VERSION` becomes **7**.
- Derived JSON files are regenerated, never hand-edited.
- No SwiftData model change: `Question` already stores `kind` as the enum.

## Content quality rules (binding, same as 7b)

1. Exactly one defensible correct option; every distractor is refutable in one
   sentence.
2. B2-C1 academic register, original text.
3. `explanationTR` (2-4 sentences) states the rule or reasoning that makes the
   key correct and names and refutes at least two specific distractors.
4. Key distribution per lesson: no key over 40 % of its questions, never three
   consecutive identical keys.
5. Options are similar in length and register; no length cue, no joke options.
6. Later lessons of a type are harder and exercise the traps real YDS
   candidates fall into (over-reading the passage, absolute words, near-synonym
   distractors, connector/tense mismatch).
7. No question is answerable without the passage or stem it belongs to.
8. All learner-facing Turkish is real Turkish, informal "sen" register.

## Testing

CI is the only place tests run (no Swift toolchain on the development machine).

- **LearningEngine tests:** the importer accepts each new kind and still
  rejects an unknown one; the assembled fixture reports the new totals.
- **App tests:**
  - Totals for the bundled package: version 7, 13 units, 82 lessons, 190 items
    (120 vocabulary, 32 grammarPoint, 38 practiceSet), 583 questions, 15
    passages.
  - The existing 7b structure test is narrowed to the grammar units
    (orders 4-8), and a new structure test covers the exam units: unit ids,
    themes and orders, lesson ids per unit, lesson shape (skill, kind, counts,
    minutes), one `practiceSet` card without an explanation, passage presence
    for reading and cloze only, and cloze blank markers.
  - The preview test: the free unit is unchanged and every new unit is locked
    (13 sections, last unit `yds-exam-unit-translation-restatement`, 9 tasks).
- **Python lint** (runs in `Swift Tests` through the drift check and locally
  through the assembly script) enforces the mechanical rules.
- **Content correctness** is enforced by a per-unit independent cold review,
  exactly as in 7b; a unit with more than five `replace` verdicts is rewritten.
- **Known gap:** the practice screens render the new kinds through the same
  generic view; CI cannot see the screens, so a reading, a cloze and an
  irrelevant-sentence lesson go on the TestFlight checklist.

## Risks

- **Volume.** 248 questions and 12 passages, the same order of magnitude as 7b;
  mitigated by the same unit-by-unit authoring-plus-review cycle.
- **New question shapes on an unchanged screen.** Paragraph completion and
  irrelevant-sentence stems are longer than existing stems; the practice
  question view already handles multi-line stems (reading and cloze), and a
  device check is on the TestFlight list.
- **Irrelevant-sentence options are numerals**, so the "options similar in
  length" rule is trivially met and the option-text uniqueness lint must not
  reject them (they are unique within a question, which is all it checks).
