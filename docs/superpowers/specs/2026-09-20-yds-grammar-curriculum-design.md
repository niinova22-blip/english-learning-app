# Slice 7b: YDS Grammar Curriculum — Design Spec

Date: 2026-09-20

## Context

Slice 7a shipped the practice-lesson infrastructure (`Question`, `Passage`,
`QuestionAttempt`, `practiceSet`/`grammarPoint` cards, `PracticeSessionView`,
topic-level FSRS, the "Tekrar: konu" plan task) plus seven sample lessons in
the FIRST unit (`Tenses` and `Conditionals` as "ders 1", two reading
passages, cloze, sentence completion, translation). 7a was built so that
7b-7d are content work, not code.

Slice 7b delivers the YDS grammar curriculum: 16 core topics, two lessons
each (the two 7a topics already provide their lesson 1). This is
overwhelmingly content authoring; the only code touched is the content
assembly script and the tests that assert content totals.

Roadmap context: 7a done; **7b (this spec)**; 7c reading + exam question
types; 7d vocabulary expansion + study techniques.

## Product decisions (user-approved)

1. **Scope: 16 topics, 2 lessons each.** Lesson 1 = rule and basic usage
   (explanation card + 8 questions). Lesson 2 = exam-level hard questions
   and traps (short "tuzaklar" summary card + 10 questions).
2. **Topics** (grouped into five new units):
   - Fiil ve zaman: Tenses (lesson 2 only), Modals, Passive Voice
   - Cümle yapıları: Conditionals (lesson 2 only), Relative Clauses, Noun
     Clauses, Reported Speech
   - Fiilimsiler ve bağlantılar: Gerunds & Infinitives, Participle Clauses,
     Conjunctions & Linkers
   - Sınav düzeyi yapılar: Inversion & Emphasis, Subjunctive
   - Kelime düzeyinde gramer: Prepositions, Comparatives, Determiners &
     Quantifiers, Articles
   "Determiners & Quantifiers" is the reading of the user's "tümceler"
   (confirmed as an assumption in the brainstorm; correct at spec review if
   wrong).
3. **Free preview: the new units are locked.** They are new units placed
   after the existing four vocabulary units, so `LessonAccessPolicy`
   (unchanged: only the lowest-ordered unit is free) keeps them behind the
   package. The free unit keeps its 3 vocabulary lessons plus the 7 sample
   practice lessons from 7a as the taste of grammar and reading.
4. **Production: unit by unit.** Each unit is authored in one task and then
   independently reviewed in a separate task by an agent that did not write
   it, solving every question cold, exactly like the 7a content gate. More
   than five `replace` verdicts in a unit means the unit is rewritten, not
   patched.

## Scope

In scope: ~30 new lessons and ~250-300 questions in JSON; new units in
`scripts/assemble-content.py`; package version 5; key-distribution lint;
updated content-total assertions in tests.

Out of scope: any new question kind or screen; new importer rules; access
policy changes; reading passages beyond what a grammar lesson needs (7c);
vocabulary expansion (7d); listening/writing/speaking/pronunciation.

## Content layout

- Files: `content/yds-academic-vocab-1/grammar/<unit-slug>/<lesson-slug>.json`,
  one lesson per file, same lesson JSON shape as the 7a practice files
  (`items` = exactly one card, `questions`).
- Ids are stable and never reused: lesson `yds-grammar-<topic>-<n>`, card
  `yds-grammar-card-<topic>-<n>`, question `<lesson id>-qNN`. The two 7a
  lessons keep their ids (`yds-practice-lesson-tenses`,
  `yds-practice-lesson-conditionals`); their lesson-2 siblings are
  `yds-grammar-tenses-2` and `yds-grammar-conditionals-2`.
- Unit orders continue after the vocabulary units: vocabulary units are
  0-3, grammar units are 4-8. Ders Yolu therefore lists vocabulary units
  first, then grammar. Lesson `order` restarts at 0 in every unit.
- Each lesson has exactly one card: `grammarPoint` with `explanationTR` (the
  rule card for lesson 1, the "tuzaklar" summary for lesson 2), skill
  `grammar`. Lesson 1 and lesson 2 of a topic are separate FSRS cards, each
  reviewed by its own due date (topic-level repetition from 7a).
- Estimated duration: lesson 1 = 8 minutes, lesson 2 = 10 minutes.
- Question kind for all 7b questions is `grammar` (YDS grammar items are
  five-option sentence-completion / error-recognition style questions).
  Translation and cloze kinds stay in their 7a/7c lessons.

## Content quality rules (binding, same as 7a plus one)

1. Exactly one defensible correct option per question; every distractor is a
   plausible learner error.
2. B2-C1 academic register; a `----` blank marker; real Turkish characters;
   informal "sen" in Turkish text.
3. `explanationTR` states the rule or evidence and refutes at least two
   named distractors; a bare restatement of the answer is a defect.
4. Key distribution per file: no key used for more than 40% of the file's
   questions and no three consecutive questions with the same key.
5. Options are similar in length and register: no length cue toward the key.
6. Lesson 2 questions test traps and contrasts YDS candidates really fall
   into (e.g. tense vs. time marker, preposition collocations), not merely
   harder vocabulary.
7. **New:** no question may be answerable by a rule stated verbatim only in
   the lesson-1 card of a DIFFERENT topic (topics stay independently
   testable).

## Assembly, versioning and validation

- `scripts/assemble-content.py` gains a `GRAMMAR_UNITS` table (unit id,
  theme/title, order 4-8, ordered lesson files) and emits those units after
  the vocabulary units. Derived JSON stays byte-stable for existing
  vocabulary lessons and the 7a practice lessons.
- `PACKAGE_VERSION` becomes 5 in the first content task that ships lessons,
  so installed apps reseed once. Existing item/lesson/question ids are
  unchanged so history survives (7a's verified 3->4 path is reused).
- Lint additions (Python, runs in the CI drift check): key distribution
  rules 4 above, per file; lesson id / card id / question id unique across
  the package; grammar lessons must have skill `grammar` and question kind
  `grammar`; lesson 1 has 8 questions and lesson 2 has 10 (exact, so
  batches cannot silently ship short).
- The Swift importer needs no changes; 7a validation already rejects
  malformed lessons.

## Testing

All verification runs in CI (no Swift toolchain locally).

- `RealContentSeedingTests` and `ContentImporterTests` currently assert exact
  totals (items, questions, passages, lesson counts per unit). Each content
  task updates those assertions with the new concrete totals in the same
  commit.
- A new real-content test asserts, from the shipped JSON: unit orders 0-8,
  grammar units present and ordered, every grammar lesson has exactly one
  `grammarPoint` card with non-empty `explanationTR`, and every question has
  5 options and a valid key.
- A preview-access test asserts a preview user sees the first unit only
  (the 3 vocabulary + 7 sample practice lessons) and all grammar units are
  locked.
- Content correctness is verified by the independent review gate per unit,
  not by unit tests; a final whole-branch review spot-checks answers across
  all units.
- Known gap: the new lessons run through the unchanged 7a screens, which
  cannot be viewed in CI; device verification stays on the TestFlight list.

## Error handling

- A content mistake cannot delete existing content: the seeder still
  validates into a temporary store before replacing (6a/7a behavior).
- Lint failures fail CI, so malformed or short lessons cannot ship.

## Task order (refined in the plan)

1. Assembly support: `GRAMMAR_UNITS` (empty table, so derived JSON is
   unchanged), key-distribution and count lint. The real-content structure
   and preview-access tests land with the first content task, because they
   assert content that does not exist yet.
2. Unit "Fiil ve zaman": author; version 5; update totals.
3. Independent review of that unit.
4. Unit "Cümle yapıları": author.
5. Independent review.
6. Unit "Fiilimsiler ve bağlantılar": author.
7. Independent review.
8. Unit "Sınav düzeyi yapılar": author.
9. Independent review.
10. Unit "Kelime düzeyinde gramer": author.
11. Independent review.
12. Final whole-branch review, then finish.
