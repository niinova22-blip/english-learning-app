# Slice 7d: Vocabulary Expansion and Study Techniques — Design Spec

Date: 2026-09-20

## Context

Slices 7a-7c filled the YDS package with practice lessons, the grammar
curriculum and the exam question types. The package is now 13 units, 82
lessons, 190 items (120 vocabulary words) and 583 questions at version 7. Two
things the standing product direction asks for are still missing: a vocabulary
bank large enough to prepare a learner for YDS, and the study techniques ("how
to solve each question type", exam management, vocabulary-learning skills).
7c deliberately left the strategy cards to this slice because the `practiceSet`
card carries no explanation; technique lessons use the `grammarPoint` card,
which shows a Turkish explanation before the questions.

Slice 9 (AI study coach) follows this slice.

## Product decisions (user-approved, 2026-09-20)

1. **Vocabulary: +480 words, 600 in total.** 8 new units of 60 words each
   (6 lessons of 10 words), themed by domain. Same item format as the existing
   120 words. No overlap with existing words.
2. **Study techniques: all three groups** — question-type strategies, exam
   management and time, vocabulary-learning techniques — as 3 new units and 18
   lessons.
3. **Every technique lesson opens with a Turkish strategy card**, then applies
   it with a short question set. One new question-kind label, `strategy`
   (Turkish scenario and knowledge questions); word-formation questions reuse
   the existing `grammar` kind.
4. **All new units are locked;** the free preview is unchanged (only the first
   unit).
5. **Same quality bar as 7b/7c,** plus vocabulary-specific lint, and an
   independent review of every unit before it counts. Learning from 7c: the
   correct option must not be the longest; option lengths stay balanced.
6. **Path order:** existing units unchanged (0-12); technique units at 13-15;
   new vocabulary units at 16-23. Order is content data and can be rearranged
   later without touching any id.

## Non-goals

- New screens or question UI, speech or pronunciation, word games.
- New goals or packages (TOEFL, Business, Travel).
- Changing the free preview, the access policy, the purchase flow or the AI
  gate.
- Re-authoring the existing 120 words.

## Units and lessons

| order | unit id | theme | lessons | items / questions |
|---|---|---|---|---|
| 13 | `yds-tech-unit-question-strategies` | `Sınav soru tipi stratejileri` | 10 | 60 questions |
| 14 | `yds-tech-unit-exam-management` | `Sınav yönetimi ve zaman` | 3 | 18 questions |
| 15 | `yds-tech-unit-vocabulary-skills` | `Kelime öğrenme teknikleri` | 5 | 40 questions |
| 16 | `yds-vocab2-unit-health-medicine` | `Health & Medicine` | 6 | 60 words |
| 17 | `yds-vocab2-unit-environment-energy` | `Environment & Energy` | 6 | 60 words |
| 18 | `yds-vocab2-unit-technology-innovation` | `Technology & Innovation` | 6 | 60 words |
| 19 | `yds-vocab2-unit-education-learning` | `Education & Learning` | 6 | 60 words |
| 20 | `yds-vocab2-unit-history-culture` | `History & Culture` | 6 | 60 words |
| 21 | `yds-vocab2-unit-psychology-behaviour` | `Psychology & Behaviour` | 6 | 60 words |
| 22 | `yds-vocab2-unit-politics-governance` | `Politics & Governance` | 6 | 60 words |
| 23 | `yds-vocab2-unit-media-communication` | `Media & Communication` | 6 | 60 words |

Totals: **66 new lessons** (18 technique + 48 vocabulary), **118 new questions**,
**498 new items** (480 vocabulary + 18 `grammarPoint`).

### Technique lessons (exact shapes, enforced by lint)

Lesson id `yds-tech-<slug>`; card id `yds-tech-card-<slug>`; question ids
`yds-tech-<slug>-qNN`. Each lesson owns exactly one `grammarPoint` card with a
non-empty Turkish `explanationTR`, and no passage.

| unit | slug | kind | skill | questions | minutes |
|---|---|---|---|---|---|
| 13 | `reading` | `strategy` | reading | 6 | 7 |
| 13 | `cloze` | `strategy` | reading | 6 | 7 |
| 13 | `sentence` | `strategy` | grammar | 6 | 7 |
| 13 | `translation` | `strategy` | reading | 6 | 7 |
| 13 | `paragraph` | `strategy` | reading | 6 | 7 |
| 13 | `irrelevant` | `strategy` | reading | 6 | 7 |
| 13 | `dialogue` | `strategy` | grammar | 6 | 7 |
| 13 | `restatement` | `strategy` | reading | 6 | 7 |
| 13 | `vocabulary-questions` | `strategy` | reading | 6 | 7 |
| 13 | `grammar-questions` | `strategy` | grammar | 6 | 7 |
| 14 | `time-allocation` | `strategy` | reading | 6 | 7 |
| 14 | `elimination` | `strategy` | reading | 6 | 7 |
| 14 | `exam-day` | `strategy` | reading | 6 | 7 |
| 15 | `prefixes` | `grammar` | grammar | 8 | 9 |
| 15 | `suffixes` | `grammar` | grammar | 8 | 9 |
| 15 | `context-clues` | `strategy` | reading | 8 | 9 |
| 15 | `synonyms-collocations` | `strategy` | reading | 8 | 9 |
| 15 | `memorisation` | `strategy` | reading | 8 | 9 |

(Skills follow the 7-skill set; a `vocabulary`-skill lesson may not carry
questions, so vocabulary technique lessons are tagged `reading` or `grammar`.)

**Strategy card (`explanationTR`)** — the Turkish teaching text in the 7b house
style: `•` bullet blocks separated by `\n\n`, an English example in each block,
and an explicit "En sık düşülen tuzak:" paragraph. It states the step-by-step
technique for that question type (for example reading: read the question
stems first, locate the paragraph, check every option against the text, beware
absolutes) and cites what the lesson's questions test.

**Strategy questions** are five-option questions like every other. They apply
the technique: short English exam items (a sentence, a mini-paragraph or a
stem) where the learner must use the taught step, or Turkish scenario
questions about exam behaviour ("Bir soruda iki dakikayı aştın; en doğru
davranış hangisi?"). Every question has exactly one defensible option, and
`explanationTR` names and refutes at least two distractors.

**Prefix/suffix lessons** use the existing `grammar` kind: word-formation items
(for example "The prefix in 'misinterpret' means ----.", or completing a
sentence with the correct derived form of a given stem).

### Vocabulary units (exact shapes, enforced by lint)

- One source file per unit: `content/yds-academic-vocab-1/vocab2/<unit-slug>.json`
  in the same document shape as the existing `batches/*.json` (unit id, theme,
  order, six lessons of ten items). Ids: lesson `yds-vocab2-lesson-<slug>-<n>`,
  item `yds-vocab2-item-<headword>` (`headword` lowercase ASCII letters and
  hyphens). Lesson `estimatedDurationMinutes` 5, skill `vocabulary`, title
  derived as `"<theme> · <n>"` by the existing rule.
- Item fields, all required: `type` `vocabulary`, `headword`, `frequencyRank`
  (positive integer), `baseDifficulty` (0.05-0.95), `definition` (Turkish, one
  sentence ending with a full stop), `exampleSentences` (exactly 3 English
  sentences that each contain the headword or an inflection), `translationTR`
  (Turkish equivalent; polysemous words list the senses the AWL usage needs),
  `collocations` (exactly 3 English collocations each containing the headword).
- Difficulty spread: lesson 1 of each unit averages about 0.3 and lesson 6
  about 0.8, so the adaptive level test (which reads `baseDifficulty`) gains
  harder candidates.
- No headword may repeat anywhere in the package (case-insensitive), including
  the existing 120.

## Code changes

- `QuestionKind` gains `strategy`.
- `scripts/assemble-content.py`: `QUESTION_KINDS` gains `strategy`; two new
  tables, `TECH_UNITS` (technique lesson files, like `GRAMMAR_UNITS`) and
  `VOCAB2_UNITS` (unit files, like `BATCH_FILES`); loaders; a lint keyed on the
  `yds-tech-` prefix (shapes above, explanation present, question counts,
  minutes, kind, skill, exactly one `grammarPoint`) and a vocabulary lint keyed
  on the `yds-vocab2-` prefix (shapes and rules above, package-wide headword
  uniqueness); the existing key-distribution lint applies. `PACKAGE_VERSION`
  becomes **8**.
- Derived JSON files are regenerated, never hand-edited.
- No SwiftData model change. The level-test candidate fetcher already reads the
  package's vocabulary items; the larger pool needs no code change (tests that
  pin the real package's word count are updated).

## Content quality rules (binding)

1. Vocabulary entries: accurate Turkish for the academic sense, honest about
   polysemy, natural example sentences in B2-C1 academic register, collocations
   that really occur, definitions that define (not just translate), no
   headword used inside its own definition in a way that makes it circular.
2. Strategy content: correct, exam-realistic advice; no claim that cannot be
   defended (no invented statistics); consistent across lessons.
3. Questions: one defensible option; refutable distractors; `explanationTR`
   names and refutes at least two distractors with correct `(A)`-`(E)` letters;
   the correct option is not systematically the longest; no junk or absurd
   distractors; key distribution valid (max 40 % of a lesson's questions per key,
   never three consecutive).
4. All learner-facing Turkish is real Turkish, informal "sen" register.

## Testing

- **LearningEngine tests:** the importer accepts `strategy`; the assembled
  fixture reports the new totals.
- **App tests:** package totals per unit task (units, lessons, items, questions,
  vocabulary items); structure tests for the technique units (unit ids, themes,
  orders, lesson ids, one `grammarPoint` card with a non-empty explanation, kind,
  skill, counts, minutes) and for the vocabulary units (unit ids, themes, orders,
  six lessons of ten `vocabulary` items with 3 examples and 3 collocations);
  the preview test (free unit unchanged, every new unit locked, last unit and
  its task count updated per task).
- **Python lint** enforces the mechanical rules on every push (`Swift Tests`
  drift check).
- **Content correctness** by per-unit independent cold review; more than five
  `replace` verdicts in a unit means rewriting the unit. For vocabulary units the
  reviewer checks every Turkish translation and definition, example naturalness
  and duplicates.
- **Known gap:** how a strategy lesson (explanation card, then questions) reads
  on device, and the harder word difficulty in the level test, are on the
  TestFlight checklist.

## Risks

- **Volume.** 480 vocabulary entries and 118 questions; mitigated by the
  unit-by-unit authoring-plus-review cycle used in 7b and 7c.
- **Translation accuracy.** Turkish equivalents of polysemous academic words are
  the main quality risk; the review checks each entry against the sense used.
- **Level test.** A larger, harder pool changes placement results; the fetcher
  needs at least 15 candidates and is unaffected, but real placement quality can
  only be judged on device.
