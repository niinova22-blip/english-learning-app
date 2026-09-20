# YDS Grammar Curriculum (Slice 7b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the YDS grammar curriculum — 16 topics × 2 lessons across five new locked units, 30 new lesson files and 272 new questions — as content only, with the assembly script and content-total assertions as the sole code changes.

**Architecture:** `scripts/assemble-content.py` gains a `GRAMMAR_UNITS` table that loads one lesson document per file from `content/yds-academic-vocab-1/grammar/<unit-slug>/` and emits five units at `order` 4-8, after the four existing vocabulary units (orders 0-3). Every grammar lesson is exactly the 7a practice-lesson shape: one `grammarPoint` card with `explanationTR` plus `grammar`-kind questions — so the Swift importer, the practice screens and `LessonAccessPolicy` are all unchanged. Correctness of the questions themselves is enforced by a per-unit independent review gate, not by unit tests; the Python lint enforces everything mechanical (ids, counts, key distribution).

**Tech Stack:** Python 3.12 content assembly (`scripts/assemble-content.py`), JSON content under `content/yds-academic-vocab-1/`, Swift 5.10 / SwiftUI / SwiftData consumers (`LearningEngine`, `EnglishApp`), GitHub Actions macOS runners (`Swift Tests`, `App Build`) for all verification.

**Spec:** `docs/superpowers/specs/2026-09-20-yds-grammar-curriculum-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification is: commit, then **push and confirm both CI workflows green** — `Swift Tests` (`.github/workflows/swift-tests.yml`, driven by `scripts/ci-test.sh`) and `App Build` (`.github/workflows/app-build.yml`, driven by `scripts/ci-app-build.sh`). A content-only task still runs both: `Swift Tests` re-runs `assemble-content.py` and diffs the derived files, `App Build` runs the App-target tests that assert the totals.
- **Pushed commits are never amended.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with a blank line and then** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- **Run the assembly script with the real Python interpreter:**
  `"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py`.
  Do **not** use bare `python`/`python3`: on this machine those may resolve to the Microsoft Store alias, which silently virtualizes file writes — the script prints "Wrote ..." while the derived JSON on disk never changes, and CI then fails the drift check with a diff you cannot reproduce locally. After every run, confirm with `git status --short` that the two derived files actually changed.
- **Never hand-edit the derived JSON.** `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json` are outputs. Edit sources under `content/`, then regenerate.
- **Avoid backticks and `$(...)` inside double-quoted bash strings** (this shell is Git Bash on Windows and the surrounding tooling mangles them). Use single-quoted heredocs for multi-line commit messages, exactly as shown in each task.
- **Tests assert concrete values.** Every content total in this plan is a computed number; write the number, never a derived expression such as `lessons.count * 2`.
- **All learner-facing Turkish is real Turkish** (`ı İ ş ğ ü ö ç`, never ASCII substitutes), informal "sen" register, UTF-8, LF, no BOM.
- **Ids are stable and never reused.** The two 7a lessons keep their existing ids (`yds-practice-lesson-tenses`, `yds-practice-lesson-conditionals`) and are not moved, renamed or re-homed by this slice.
- **Content quality rules (binding on every authored question)** — the spec's rules, plus the authoring rulings this plan adds:
  1. Exactly one defensible correct option. Every distractor must be refutable in one sentence. Any "well, B is arguably fine too" is a defect, not a nuance.
  2. B2-C1 academic register (economics, science, policy, law, technology), impersonal prose, the YDS blank marker `----` in the stem.
  3. `explanationTR` (2-4 sentences) states the rule that makes the key correct **and** names and refutes at least two specific distractors. A bare restatement of the answer is a defect.
  4. Key distribution per file: no key used for more than 40% of that file's questions, and never three consecutive questions (by `order`) with the same key. The lint enforces both.
  5. Options are similar in length and register — no length cue toward the key, no joke or obviously-wrong filler options.
  6. Lesson 2 tests traps real YDS candidates fall into (tense vs. time marker, perfect modal vs. past obligation, inversion placement, preposition collocation), not merely harder vocabulary.
  7. **Topic independence:** no question may be answerable only by a rule stated verbatim in a *different* topic's card. The "Topic boundaries" table below is the binding division; when two topics touch, the question must be solvable inside its own topic's card.
  8. **One blank per question.** Exactly one `----` per stem; no two-blank YDS items in 7b (the practice screen renders a single stem plus five plain options).
  9. **Never use a bare dash or "(no article)" as an option.** Where the zero article is the answer, put the whole noun phrase in every option (`"primary education"` vs `"the primary education"`).
  10. Grammar lessons carry **no passage**: `passage` is absent and every question's `passageID` is `null`.

---

## Naming and id contract (binding — the lint enforces all of it)

- Lesson file: `content/yds-academic-vocab-1/grammar/<unit-slug>/<topic>-<n>.json`, one lesson document per file, **without** an `order` key (position in `GRAMMAR_UNITS` assigns it).
- Lesson id: `yds-grammar-<topic>-<n>` where `n` is `1` or `2`.
- Card id: `yds-grammar-card-<topic>-<n>` (mechanically `"yds-grammar-card-" + lesson_id[len("yds-grammar-"):]`).
- Question id: `<lesson id>-q<NN>`, `NN` zero-padded from `01`, and `order` = `NN - 1`.
- Lesson 1: 8 questions, `estimatedDurationMinutes` 8. Lesson 2: 10 questions, `estimatedDurationMinutes` 10.
- Every grammar lesson: `"skill": "grammar"`, exactly one item of `"type": "grammarPoint"`, every question `"kind": "grammar"`.
- Card fields: `headword` (English topic label), `frequencyRank` (fixed per lesson, see the unit tables), `baseDifficulty` `0.5` for lesson 1 and `0.6` for lesson 2, `definition` (one Turkish line), `exampleSentences: []`, `translationTR` (the Turkish lesson title), `collocations: []`, `explanationTR` (the rule card / "tuzaklar" summary). `baseDifficulty` is safe to vary: `LevelTestCandidateFetcher` filters to `type == .vocabulary`, so grammar cards never enter the level test.

### Unit table (ids, orders and themes are contractual)

| order | unit id | theme | directory | lessons | questions |
|---|---|---|---|---|---|
| 4 | `yds-grammar-unit-verbs-and-tenses` | `Fiil ve zaman` | `grammar/verbs-and-tenses/` | 5 | 46 |
| 5 | `yds-grammar-unit-sentence-structures` | `Cümle yapıları` | `grammar/sentence-structures/` | 7 | 64 |
| 6 | `yds-grammar-unit-verbals-and-linkers` | `Fiilimsiler ve bağlantılar` | `grammar/verbals-and-linkers/` | 6 | 54 |
| 7 | `yds-grammar-unit-exam-level-structures` | `Sınav düzeyi yapılar` | `grammar/exam-level-structures/` | 4 | 36 |
| 8 | `yds-grammar-unit-word-level-grammar` | `Kelime düzeyinde gramer` | `grammar/word-level-grammar/` | 8 | 72 |

30 new lessons, 30 new `grammarPoint` cards, **272** new questions (14 topics × 18, plus Tenses and Conditionals contributing their lesson 2 only, 10 each).

### Running totals to assert after each task (arithmetic, computed once here)

Baseline on the branch today: 4 units, 19 lessons, 127 items (120 `vocabulary` + 2 `grammarPoint` + 5 `practiceSet`), 63 questions, 3 passages, package version 4.

| After task | units | lessons | items | `grammarPoint` items | questions | passages | version |
|---|---|---|---|---|---|---|---|
| 2 (Fiil ve zaman) | 5 | 24 | 132 | 7 | 109 | 3 | 5 |
| 4 (Cümle yapıları) | 6 | 31 | 139 | 14 | 173 | 3 | 5 |
| 6 (Fiilimsiler ve bağlantılar) | 7 | 37 | 145 | 20 | 227 | 3 | 5 |
| 8 (Sınav düzeyi yapılar) | 8 | 41 | 149 | 24 | 263 | 3 | 5 |
| 10 (Kelime düzeyinde gramer) | 9 | 49 | 157 | 32 | 335 | 3 | 5 |

`vocabulary` items stay 120 and `practiceSet` items stay 5 throughout.

### Topic boundaries (enforcement of quality rule 7)

| Topic | Owns | Must NOT be the tested point |
|---|---|---|
| Tenses | tense choice driven by time markers, sequence of tenses | conditional tense pairings (Conditionals) |
| Modals | modal meaning, perfect modals, modal passive | subjunctive `should` after `suggest` (Subjunctive) |
| Passive Voice | passive formation, impersonal passive, causative | participle-clause reduction (Participle Clauses) |
| Conditionals | type 1/2/3, mixed, `unless`/`but for`/`provided that`, conditional inversion `Had/Were/Should` | `wish` / `if only` / `it's high time` (Subjunctive); fronted negative adverbials (Inversion) |
| Relative Clauses | defining vs non-defining, preposition + which, quantifier + of which, reduced relatives | noun-clause `what` (Noun Clauses) |
| Noun Clauses | that/wh-/whether clauses, `what` vs `that`, anticipatory `it` | backshift (Reported Speech) |
| Reported Speech | backshift, reporting-verb patterns, reported questions/commands | `suggest/demand + that + base` (Subjunctive) |
| Gerunds & Infinitives | verb patterns, meaning-changing verbs, perfect/passive verbals | bare participle clauses (Participle Clauses) |
| Participle Clauses | participial reduction, absolute constructions, dangling subject | verb + gerund patterns (Gerunds & Infinitives) |
| Conjunctions & Linkers | conjunction vs connector vs preposition, paired conjunctions | `not only ... but also` **with inversion** (Inversion) |
| Inversion & Emphasis | fronted negative adverbials, `Only ...`, conditional inversion, clefts, emphatic `do` | plain conditional tense pairing (Conditionals) |
| Subjunctive | mandative subjunctive, `It is essential that`, `wish`/`if only`, `would rather`, `it's high time`, `as if` | ordinary modal meaning (Modals) |
| Prepositions | verb/adjective/noun + preposition collocations, complex prepositions | preposition + relative pronoun (Relative Clauses) |
| Comparatives | comparative/superlative forms, `the more ... the more`, comparison parallelism | quantifier agreement (Determiners) |
| Determiners & Quantifiers | quantifiers, distributives, demonstratives, quantifier-verb agreement | article choice (Articles) |
| Articles | a/an/the/zero, institutions, geography, `the + adjective`, fixed phrases | quantifier agreement (Determiners) |

---

## Task order (spec "Task order", with the 7a split preserved)

The spec's order is kept exactly. As in 7a, each spec "unit" step is split into an **authoring** task and an **independent review** task, because content reviewed by its own author is not reviewed. Task 1 must reach CI before Task 2: Task 2's derived JSON contains lessons that only Task 1's loader and lint know how to produce.

---

## Task 1: Assembly support — `GRAMMAR_UNITS` (empty), grammar-lesson lint, key-distribution lint

**Files:**
- Modify: `scripts/assemble-content.py`
- Verify unchanged: `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`, `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`

**Interfaces:**
- Consumes: the existing `assemble()` / `validate_content()` / `enrich_lessons()` pipeline and `attach_practice_lessons()`.
- Produces: module-level `GRAMMAR_DIR`, `GRAMMAR_UNITS` (empty list in this task), `GRAMMAR_LESSON_ID_PREFIX = "yds-grammar-"`, `GRAMMAR_LESSON_ID_RE`, `GRAMMAR_LESSON_SHAPE = {"1": (8, 8), "2": (10, 10)}`; functions `load_grammar_units() -> list[dict]`, `validate_key_distribution(lesson_id, questions) -> None`, `validate_grammar_lesson(lesson) -> None`; `validate_content(package)` additionally rejects duplicate unit ids, duplicate lesson ids and non-contiguous unit orders. Later tasks only append entries to `GRAMMAR_UNITS`.

**Why the table starts empty:** shipping the loader and the lint separately from any content keeps this commit provably byte-neutral on the derived JSON, so a red CI run here can only mean the script itself broke.

- [ ] **Step 1: Write the failing lint check (red)**

There is no Python test harness in this repo, so the lint's red/green cycle is a throwaway script in the scratchpad that imports the assembly module and asserts each rule. Write it first and watch it fail.

Save as `C:/Users/niino/AppData/Local/Temp/claude/lint-check.py`:

```python
"""Red/green check for the Slice 7b lint additions in scripts/assemble-content.py.
Run from the repository root. Prints PASS lines; raises on the first failure."""
import copy
import importlib.util
import os

spec = importlib.util.spec_from_file_location("assemble", os.path.join("scripts", "assemble-content.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def question(qid, order, key):
    return {
        "id": qid, "kind": "grammar", "order": order,
        "prompt": "The committee ---- the report.",
        "options": ["a", "b", "c", "d", "e"],
        "correctIndex": key, "explanationTR": "Açıklama.", "passageID": None,
    }


def grammar_lesson(lesson_id="yds-grammar-modals-1", count=8, keys=None):
    keys = keys or [0, 1, 2, 3, 4, 0, 1, 2, 3, 4][:count]
    return {
        "id": lesson_id, "order": 0, "estimatedDurationMinutes": 8 if lesson_id.endswith("-1") else 10,
        "title": "Kipler (Modals)", "skill": "grammar",
        "items": [{
            "id": "yds-grammar-card-" + lesson_id[len("yds-grammar-"):], "type": "grammarPoint",
            "headword": "Modals", "frequencyRank": 2001, "baseDifficulty": 0.5,
            "definition": "Kipler.", "exampleSentences": [], "translationTR": "Kipler",
            "collocations": [], "explanationTR": "Kural.",
        }],
        "questions": [question(f"{lesson_id}-q{i + 1:02d}", i, keys[i]) for i in range(count)],
    }


def package(lessons):
    return {"units": [{"id": "yds-grammar-unit-verbs-and-tenses", "theme": "Fiil ve zaman", "order": 0, "lessons": lessons}]}


def expect_failure(pkg, needle):
    try:
        mod.validate_content(pkg)
    except ValueError as error:
        assert needle in str(error), f"expected {needle!r} in {error!r}"
        print(f"PASS rejected: {needle}")
        return
    raise AssertionError(f"expected a ValueError mentioning {needle!r}")


# 1. A well-formed grammar lesson passes.
mod.validate_content(package([grammar_lesson()]))
print("PASS accepted a well-formed grammar lesson")

# 2. Wrong question count for a lesson 1.
expect_failure(package([grammar_lesson(count=7, keys=[0, 1, 2, 3, 4, 0, 1])]), "exactly 8 questions")

# 3. Wrong question count for a lesson 2.
expect_failure(package([grammar_lesson("yds-grammar-modals-2", count=8)]), "exactly 10 questions")

# 4. Wrong duration.
bad = package([grammar_lesson()])
bad["units"][0]["lessons"][0]["estimatedDurationMinutes"] = 12
expect_failure(bad, "estimatedDurationMinutes")

# 5. Key used more than 40% of the time (4 of 8).
expect_failure(package([grammar_lesson(keys=[0, 0, 1, 0, 2, 0, 3, 4])]), "max 40%")

# 6. Three consecutive questions with the same key.
expect_failure(package([grammar_lesson(keys=[1, 0, 0, 0, 2, 3, 4, 1])]), "three consecutive")

# 7. Question id does not follow <lesson id>-qNN.
bad = package([grammar_lesson()])
bad["units"][0]["lessons"][0]["questions"][2]["id"] = "yds-grammar-modals-1-q99"
expect_failure(bad, "must be named")

# 8. Card id does not match the lesson id.
bad = package([grammar_lesson()])
bad["units"][0]["lessons"][0]["items"][0]["id"] = "yds-grammar-card-modals-9"
expect_failure(bad, "card id")

# 9. Non-grammar question kind inside a grammar lesson.
bad = package([grammar_lesson()])
bad["units"][0]["lessons"][0]["questions"][0]["kind"] = "cloze"
expect_failure(bad, "kind 'grammar'")

# 10. Duplicate lesson id across units.
first = grammar_lesson()
second = copy.deepcopy(first)
pkg = {"units": [
    {"id": "unit-a", "theme": "A", "order": 0, "lessons": [first]},
    {"id": "unit-b", "theme": "B", "order": 1, "lessons": [second]},
]}
expect_failure(pkg, "duplicate lesson id")

# 11. Non-contiguous unit orders.
pkg = {"units": [
    {"id": "unit-a", "theme": "A", "order": 0, "lessons": []},
    {"id": "unit-b", "theme": "B", "order": 2, "lessons": []},
]}
expect_failure(pkg, "unit orders")

# 12. The real shipped package still assembles and validates.
real = mod.assemble()
assert len(real["units"]) == 4, len(real["units"])
assert sum(len(l.get("questions", [])) for u in real["units"] for l in u["lessons"]) == 63
print("PASS real package still assembles: 4 units, 63 questions")
print("ALL CHECKS PASSED")
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" C:/Users/niino/AppData/Local/Temp/claude/lint-check.py
```

Expected: `AssertionError: expected a ValueError mentioning 'exactly 8 questions'` at check 2 (check 1 passes today, because `validate_content` currently accepts anything with the right question shape).

- [ ] **Step 3: Add the grammar table, loader and constants**

In `scripts/assemble-content.py`, add `import re` under `import os`, then insert after the `PRACTICE_CARD_TYPES` line:

```python
GRAMMAR_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "grammar")

# Slice 7b grammar units, emitted after the four vocabulary units (orders
# 0-3). Each entry's `files` are relative to GRAMMAR_DIR and hold ONE lesson
# document each, without an `order` key: position in the list is the lesson
# order, restarting at 0 in every unit. The table is filled in unit by unit;
# an empty table leaves the derived JSON byte-identical.
GRAMMAR_UNITS = []

GRAMMAR_LESSON_ID_PREFIX = "yds-grammar-"
GRAMMAR_LESSON_ID_RE = re.compile(r"^yds-grammar-[a-z0-9-]+-(1|2)$")
# lesson suffix -> (exact question count, exact estimatedDurationMinutes).
# Exact, not minimum: a short batch must never ship silently.
GRAMMAR_LESSON_SHAPE = {"1": (8, 8), "2": (10, 10)}
# No key may be used for more than this share of one file's questions.
MAX_KEY_SHARE = 0.4
```

Add the loader next to `load_practice_lessons`:

```python
def load_grammar_units():
    """Builds the Slice 7b grammar units from GRAMMAR_UNITS. Lesson `order`
    comes from the position in `files`, so reordering a unit is a one-line
    change and ids never have to move."""
    units = []
    for unit_spec in GRAMMAR_UNITS:
        lessons = []
        for order, filename in enumerate(unit_spec["files"]):
            path = os.path.join(GRAMMAR_DIR, filename)
            with open(path, "r", encoding="utf-8") as f:
                lesson = json.load(f)
            if not lesson["id"].startswith(GRAMMAR_LESSON_ID_PREFIX):
                raise ValueError(
                    f"grammar lesson {lesson['id']} (from {filename}) must start with "
                    f"{GRAMMAR_LESSON_ID_PREFIX!r}, otherwise the grammar lint skips it"
                )
            lesson = dict(lesson)
            lesson["order"] = order
            lessons.append(lesson)
        units.append({
            "id": unit_spec["id"],
            "theme": unit_spec["theme"],
            "order": unit_spec["order"],
            "lessons": lessons,
        })
    return units
```

- [ ] **Step 4: Add the two new lint functions**

Insert both above `validate_content`:

```python
def validate_key_distribution(lesson_id, questions):
    """Spec quality rule 4: a learner must not be able to pattern-match the
    answer key. Applies to EVERY lesson with questions, including the 7a
    practice files (all of which already satisfy it)."""
    if not questions:
        return
    ordered = sorted(questions, key=lambda q: q["order"])
    counts = {}
    for q in ordered:
        counts[q["correctIndex"]] = counts.get(q["correctIndex"], 0) + 1
    for key, count in sorted(counts.items()):
        if count > MAX_KEY_SHARE * len(ordered):
            raise ValueError(
                f"lesson {lesson_id}: key {key} is used {count} of {len(ordered)} times "
                f"(max 40% of a file's questions)"
            )
    run = 1
    for previous, current in zip(ordered, ordered[1:]):
        run = run + 1 if current["correctIndex"] == previous["correctIndex"] else 1
        if run >= 3:
            raise ValueError(
                f"lesson {lesson_id}: three consecutive questions share key {current['correctIndex']}"
            )


def validate_grammar_lesson(lesson):
    """Shape rules for Slice 7b grammar lessons, keyed off the lesson id
    prefix. The two Slice 7a grammar lessons (yds-practice-lesson-tenses,
    yds-practice-lesson-conditionals) keep their original ids and are
    deliberately outside this check -- they are lesson 1 of their topics and
    already have exactly 8 grammar questions each, but their ids are
    contractual and must not be renamed."""
    lesson_id = lesson["id"]
    match = GRAMMAR_LESSON_ID_RE.match(lesson_id)
    if match is None:
        raise ValueError(
            f"grammar lesson id {lesson_id!r} must look like yds-grammar-<topic>-1 or yds-grammar-<topic>-2"
        )
    expected_questions, expected_minutes = GRAMMAR_LESSON_SHAPE[match.group(1)]
    if lesson["skill"] != "grammar":
        raise ValueError(f"grammar lesson {lesson_id} must have skill 'grammar', found {lesson['skill']!r}")
    if lesson["estimatedDurationMinutes"] != expected_minutes:
        raise ValueError(
            f"grammar lesson {lesson_id} must have estimatedDurationMinutes {expected_minutes}, "
            f"found {lesson['estimatedDurationMinutes']}"
        )
    if "passage" in lesson:
        raise ValueError(f"grammar lesson {lesson_id} must not carry a passage")

    cards = [item for item in lesson["items"] if item["type"] == "grammarPoint"]
    if len(lesson["items"]) != 1 or len(cards) != 1:
        raise ValueError(
            f"grammar lesson {lesson_id} must own exactly one grammarPoint item, "
            f"found {len(lesson['items'])} items ({len(cards)} grammarPoint)"
        )
    expected_card_id = "yds-grammar-card-" + lesson_id[len(GRAMMAR_LESSON_ID_PREFIX):]
    if cards[0]["id"] != expected_card_id:
        raise ValueError(
            f"grammar lesson {lesson_id}: card id {cards[0]['id']!r} must be {expected_card_id!r}"
        )

    questions = lesson.get("questions", [])
    if len(questions) != expected_questions:
        raise ValueError(
            f"grammar lesson {lesson_id} must have exactly {expected_questions} questions, found {len(questions)}"
        )
    for index, question in enumerate(sorted(questions, key=lambda q: q["order"])):
        if question["kind"] != "grammar":
            raise ValueError(
                f"question {question['id']} in {lesson_id} must have kind 'grammar', found {question['kind']!r}"
            )
        if question["order"] != index:
            raise ValueError(
                f"lesson {lesson_id} question orders must be 0..{expected_questions - 1} with no gaps"
            )
        expected_qid = f"{lesson_id}-q{index + 1:02d}"
        if question["id"] != expected_qid:
            raise ValueError(f"question at order {index} in {lesson_id} must be named {expected_qid!r}")
        if question.get("passageID") is not None:
            raise ValueError(f"question {question['id']} in {lesson_id} must have passageID null")
```

- [ ] **Step 5: Wire the new rules into `validate_content` and `assemble`**

In `validate_content`, replace the two opening lines of the function body

```python
    question_ids = set()
    item_ids = set()
    passage_ids = set()
    for unit in package["units"]:
```

with

```python
    question_ids = set()
    item_ids = set()
    passage_ids = set()
    unit_ids = set()
    lesson_ids = set()

    orders = sorted(unit["order"] for unit in package["units"])
    if orders != list(range(len(package["units"]))):
        raise ValueError(f"unit orders must be 0..{len(package['units']) - 1} with no gaps, found {orders}")

    for unit in package["units"]:
        if unit["id"] in unit_ids:
            raise ValueError(f"duplicate unit id {unit['id']}")
        unit_ids.add(unit["id"])
```

Then, immediately after the existing `lesson_id = lesson["id"]` line inside the lesson loop, add:

```python
            if lesson_id in lesson_ids:
                raise ValueError(f"duplicate lesson id {lesson_id}")
            lesson_ids.add(lesson_id)
```

and, at the very end of the lesson loop body (after the `orders.add(question["order"])` line, dedented to the lesson level), add:

```python
            validate_key_distribution(lesson_id, questions)
            if lesson_id.startswith(GRAMMAR_LESSON_ID_PREFIX):
                validate_grammar_lesson(lesson)
```

Note the name collision: the existing loop already uses a local `orders` set for question orders. Rename that local to `question_orders` in its three occurrences (`question_orders = set()`, `if question["order"] in question_orders:`, `question_orders.add(question["order"])`) so the new unit-order list keeps its name.

Finally, in `assemble`, append the grammar units:

```python
    units = attach_practice_lessons(load_units()) + load_grammar_units()
```

- [ ] **Step 6: Run the lint check and confirm it passes (green)**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" C:/Users/niino/AppData/Local/Temp/claude/lint-check.py
```

Expected: twelve `PASS` lines and `ALL CHECKS PASSED`. Check 12 proves the four shipped units and 63 existing questions still pass every rule, including the new key-distribution rule (verified by hand against the shipped files: the largest per-file key share today is 2 of 6 = 33% in `reading-climate-policy.json`, and no file has three consecutive identical keys).

- [ ] **Step 7: Regenerate and prove the derived JSON did not move**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: `scripts/assemble-content.py` is the **only** modified file. If either derived JSON appears, `GRAMMAR_UNITS` is not empty or `assemble()` was changed incorrectly — fix before committing, because the CI drift check compares exactly these bytes.

- [ ] **Step 8: Commit**

```bash
git add scripts/assemble-content.py
git commit -m "$(cat <<'EOF'
Add grammar unit assembly support and content lint for Slice 7b

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 9: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Expected: both green, with no test changes — the shipped package is byte-identical, so every existing assertion (127 items, 63 questions, version 4) still holds.

---

## Task 2: Unit "Fiil ve zaman" — 5 lessons, 46 questions, package version 5

**Files:**
- Create: `content/yds-academic-vocab-1/grammar/verbs-and-tenses/tenses-2.json`
- Create: `content/yds-academic-vocab-1/grammar/verbs-and-tenses/modals-1.json`
- Create: `content/yds-academic-vocab-1/grammar/verbs-and-tenses/modals-2.json`
- Create: `content/yds-academic-vocab-1/grammar/verbs-and-tenses/passive-voice-1.json`
- Create: `content/yds-academic-vocab-1/grammar/verbs-and-tenses/passive-voice-2.json`
- Modify: `scripts/assemble-content.py` (`GRAMMAR_UNITS` first entry, `PACKAGE_VERSION` 4 → 5)
- Regenerate (never hand-edit): `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json`, `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`
- Modify: `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`
- Modify: `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's `GRAMMAR_UNITS`, `load_grammar_units()`, `validate_grammar_lesson()`, `validate_key_distribution()`.
- Produces: package version **5**; unit `yds-grammar-unit-verbs-and-tenses` at order 4 with lesson ids `yds-grammar-tenses-2`, `yds-grammar-modals-1`, `yds-grammar-modals-2`, `yds-grammar-passive-voice-1`, `yds-grammar-passive-voice-2`; the reusable Swift tests `test_bundledPackage_grammarUnits_areStructurallySound()` (in `RealContentSeedingTests`) and `test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked()` (in `CoursePathViewModelTests`), which every later unit task updates rather than duplicates.

### Lesson inventory (contractual)

| order | file | lesson id | card id | title | headword | freqRank | baseDiff | min | questions |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `tenses-2.json` | `yds-grammar-tenses-2` | `yds-grammar-card-tenses-2` | `Zamanlar: Tuzaklar` | `Tenses (Traps)` | 2000 | 0.6 | 10 | 10 |
| 1 | `modals-1.json` | `yds-grammar-modals-1` | `yds-grammar-card-modals-1` | `Kipler (Modals)` | `Modals` | 2001 | 0.5 | 8 | 8 |
| 2 | `modals-2.json` | `yds-grammar-modals-2` | `yds-grammar-card-modals-2` | `Kipler: Tuzaklar` | `Modals (Traps)` | 2002 | 0.6 | 10 | 10 |
| 3 | `passive-voice-1.json` | `yds-grammar-passive-voice-1` | `yds-grammar-card-passive-voice-1` | `Edilgen Yapı (Passive Voice)` | `Passive Voice` | 2003 | 0.5 | 8 | 8 |
| 4 | `passive-voice-2.json` | `yds-grammar-passive-voice-2` | `yds-grammar-card-passive-voice-2` | `Edilgen Yapı: Tuzaklar` | `Passive Voice (Traps)` | 2004 | 0.6 | 10 | 10 |

Question ids: `yds-grammar-tenses-2-q01` … `-q10`, `yds-grammar-modals-1-q01` … `-q08`, `yds-grammar-modals-2-q01` … `-q10`, `yds-grammar-passive-voice-1-q01` … `-q08`, `yds-grammar-passive-voice-2-q01` … `-q10`. 46 questions total.

### Per-lesson topic scope (what each lesson must cover)

**`yds-grammar-tenses-2` — Zamanlar: Tuzaklar (10 questions).** Lesson 1 already shipped as 7a's `yds-practice-lesson-tenses`, so this lesson is traps only:
- `by the time` + past main clause → past perfect; `by 2030` / `by the end of the decade` → future perfect.
- `since` / `for` / `so far` → present perfect vs. `in 2019` / `two years ago` / `last quarter` → past simple.
- present perfect continuous (duration, often still going) vs. present perfect (result).
- no `will` in time clauses: `when / as soon as / until / once` take present or present perfect.
- `It is the first time (that) ... have + V3`; `This is the third time ... has + V3`.
- `no sooner had ... than`, `hardly had ... when` — tense pairing only (the *inversion* is Inversion's topic; here the stem gives the inversion and asks for the tense).
- `used to + V1` (past habit) vs. `be/get used to + V-ing` (accustomed).
- past perfect continuous for a cause that stopped (`had been working ... before`).
- sequence of tenses across two past events in one sentence.

**`yds-grammar-modals-1` — Kipler (8 questions).** Core meanings:
- ability and its past/future forms: `can` / `could` / `be able to` (`was able to` for a single achieved act).
- obligation: `must` (speaker's own) vs. `have to` (external), and the critical contrast `mustn't` (prohibition) vs. `don't have to` (no obligation).
- past obligation: `had to` (there is no past `must`).
- advice: `should` / `ought to` / `had better` (`had better` = warning with a consequence).
- permission and polite requests: `may` / `can` / `could`.
- present deduction: `must be` (certain positive) / `can't be` (certain negative) / `may, might, could be` (possible).
- `need to` vs. `needn't`.

**`yds-grammar-modals-2` — Kipler: Tuzaklar (10 questions).** Exam-level:
- perfect modals: `must have V3` (past deduction) vs. `had to V1` (past obligation) — the single most-tested trap.
- `can't have V3` (certain it did not happen) vs. `couldn't V1`.
- `should have V3` / `ought to have V3` (unfulfilled obligation, regret) vs. `shouldn't have V3`.
- `need not have V3` (did it unnecessarily) vs. `didn't need to V1` (was not necessary, probably not done).
- `may / might have V3` (past possibility); `could have V3` (unrealized possibility).
- modal + passive: `must be reviewed`, `should have been reported`, `cannot be explained`.
- `be supposed to` / `be to` for arrangements and expectations.
- `would rather + V1` vs. `would rather have V3` (boundary: `would rather + subject + past` belongs to Subjunctive; here only the same-subject bare-infinitive form).

**`yds-grammar-passive-voice-1` — Edilgen Yapı (8 questions).** Formation and basic use:
- passive across tenses: `is/are + V3`, `was/were + V3`, `has/have been + V3`, `had been + V3`, `will be + V3`, `is being + V3`.
- when the agent is kept (`by the committee`) and when it is dropped.
- passive with modals: `must be submitted`, `can be measured`.
- passive of verbs with two objects (`The applicants were sent a confirmation`).
- intransitive verbs have no passive (`occur`, `happen`, `rise`, `emerge`, `consist of`) — used as distractors.
- `get`-passive in less formal registers.

**`yds-grammar-passive-voice-2` — Edilgen Yapı: Tuzaklar (10 questions).** Exam-level:
- impersonal passive: `It is believed / reported / estimated that ...` and its raised form `X is believed to be ...` / `X is thought to have been ...`.
- passive infinitive and gerund: `to be examined`, `to have been examined`, `being examined`, `having been examined`.
- causative: `have / get something done`, `have someone do something`, `get someone to do something`.
- prepositional and phrasal verbs keep their preposition in the passive: `was dealt with`, `was looked into`, `is referred to as`, `was done away with`.
- passive with a perfect modal: `should have been notified`.
- the transitivity trap: `The accident was occurred` / `Prices were risen` are wrong — these appear as distractors, never as keys.
- passive in a reduced relative (`the factors examined in the study`) — the boundary with Participle Clauses is kept by testing the *passive form*, with the reduction already given in the stem.

### Card `explanationTR` requirements

Each card's `explanationTR` is the lesson's teaching text: a short Turkish rule summary in the 7a house style (bullet lines with `•`, `\n\n` between blocks, at least one full English example sentence per block, and for lesson 2 an explicit "En sık düşülen tuzak:" paragraph). Every rule the lesson's questions test must appear in its own card — that is what makes quality rule 7 checkable.

Reference shape (this is the `yds-grammar-modals-1` card, ready to ship):

```json
{
  "id": "yds-grammar-card-modals-1",
  "type": "grammarPoint",
  "headword": "Modals",
  "frequencyRank": 2001,
  "baseDifficulty": 0.5,
  "definition": "Yetenek, zorunluluk, tahmin ve izin bildiren kip yardımcı fiilleri.",
  "exampleSentences": [],
  "translationTR": "Kipler",
  "collocations": [],
  "explanationTR": "Kip fiilleri (modals) tek başına anlam taşımaz; cümleye YETENEK, ZORUNLULUK, TAHMİN veya İZİN anlamı ekler. Hepsinin ardından yalın fiil gelir (to almaz).\n\n• Yetenek: can (şimdi), could (geçmişte genel yetenek), be able to (her zamanda çekilebilir). Geçmişte TEK bir seferlik başarı için could değil was/were able to kullanılır: After three attempts, the team was able to isolate the compound.\n\n• Zorunluluk: must konuşanın kendi kararıdır, have to dışarıdan gelen kuraldır. Geçmişte must'ın karşılığı yoktur; had to kullanılır.\n\n• En kritik ayrım: mustn't = YASAK, don't have to = GEREK YOK. Applicants mustn't submit two forms (yasak) ≠ Applicants don't have to submit two forms (isteğe bağlı).\n\n• Öneri: should ve ought to eşdeğerdir; had better ise sonucu kötü olacak bir uyarıdır: You had better check the figures before the audit.\n\n• Tahmin: must be (kesin öyle), can't be (kesin değil), may/might/could be (olabilir). Olumsuz kesinlik için mustn't be DEĞİL can't be kullanılır.\n\nÖrnek: The building is empty at this hour, so the alarm can't be genuine."
}
```

### Worked exemplars (ready to ship; the style bar for the other 43)

**`yds-grammar-modals-1-q01`**

```json
{
  "id": "yds-grammar-modals-1-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "Since the original samples had been contaminated, the researchers ---- repeat the entire experiment; there was simply no alternative.",
  "options": [
    "must",
    "had to",
    "should",
    "could",
    "might"
  ],
  "correctIndex": 1,
  "explanationTR": "Cümle geçmişte gerçekleşmiş bir ZORUNLULUĞU anlatıyor ve «there was simply no alternative» bunu doğruluyor; must'ın geçmiş biçimi olmadığı için had to gerekir. (A) must yalnızca şimdiki zamanda zorunluluk bildirir, geçmişe çekilemez. (C) should zorunluluk değil ÖNERİ verir, oysa burada seçenek yok. (D) could yetenek/olasılık, (E) might ise ihtimal bildirir; ikisi de «başka çare yoktu» anlamını karşılamaz.",
  "passageID": null
}
```

**`yds-grammar-modals-2-q01`**

```json
{
  "id": "yds-grammar-modals-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The figures in the two tables are identical down to the last decimal, so the assistant ---- the same data set twice by mistake.",
  "options": [
    "might not have entered",
    "must have entered",
    "should have entered",
    "need not have entered",
    "would have entered"
  ],
  "correctIndex": 1,
  "explanationTR": "Elde kesin bir kanıt var (rakamlar son haneye kadar aynı), yani geçmişe yönelik KESİN TAHMİN gerekir: must have V3. (C) should have entered «girmeliydi ama girmedi» demek, oysa veri girilmiş. (D) need not have entered «gereksiz yere girmiş» anlamına gelir; cümlede gereksizlik değil hata var. (A) olumsuz ihtimal, (E) ise gerçekleşmemiş bir durumu anlatır; ikisi de kanıtla çelişir.",
  "passageID": null
}
```

**`yds-grammar-passive-voice-2-q01`**

```json
{
  "id": "yds-grammar-passive-voice-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The virus ---- to have originated in a remote farming region, although no conclusive evidence has yet been produced.",
  "options": [
    "believes",
    "is believing",
    "is believed",
    "has believed",
    "was believing"
  ],
  "correctIndex": 2,
  "explanationTR": "«It is believed that the virus originated ...» yapısının yükseltilmiş biçimi «The virus is believed to have originated ...»dır; özne eylemi yapan değil, hakkında inanılan şeydir, bu yüzden edilgen gerekir. (A) ve (D) etken; virüsün bir şeye inanması anlamsız olur. (B) ve (E) ise believe gibi durum fiillerinin almadığı sürerlik biçimleridir. Ayrıca «to have originated» geçmişe dönük mastar olduğu için ana fiil geniş zamanda kalır.",
  "passageID": null
}
```

### Lesson file shape

```json
{
  "id": "yds-grammar-modals-1",
  "estimatedDurationMinutes": 8,
  "title": "Kipler (Modals)",
  "skill": "grammar",
  "items": [ "... the single grammarPoint card, exactly as shown above ..." ],
  "questions": [ "... 8 question objects, q01..q08, order 0..7 ..." ]
}
```

No `order` key (the loader assigns it), no `passage` key, every question's `passageID` is `null`.

- [ ] **Step 1: Author the five lesson files**

Write all five files to the inventory and the topic scopes above, applying every quality rule in Global Constraints and starting from the three worked exemplars. Plan each file's keys before writing so the distribution lint passes: for an 8-question file use each of 0-4 at most three times (e.g. `[1, 3, 0, 2, 4, 1, 3, 0]`), for a 10-question file at most four times (e.g. `[2, 0, 3, 1, 4, 2, 0, 3, 1, 4]`), and never repeat a key three times in a row.

- [ ] **Step 2: Register the unit in `scripts/assemble-content.py`**

Replace `GRAMMAR_UNITS = []` with:

```python
GRAMMAR_UNITS = [
    {
        "id": "yds-grammar-unit-verbs-and-tenses",
        "theme": "Fiil ve zaman",
        "order": 4,
        "files": [
            "verbs-and-tenses/tenses-2.json",
            "verbs-and-tenses/modals-1.json",
            "verbs-and-tenses/modals-2.json",
            "verbs-and-tenses/passive-voice-1.json",
            "verbs-and-tenses/passive-voice-2.json",
        ],
    },
]
```

and bump the version with its comment:

```python
# 5: Slice 7b adds the grammar curriculum units (orders 4-8). Bumping this
# makes installed apps re-import the package; every existing id is unchanged,
# so FSRS history survives the reseed.
PACKAGE_VERSION = 5
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
git diff --stat
```

Expected: both derived JSON files listed as modified. If they are not, the Microsoft Store Python alias swallowed the writes — re-run with the full interpreter path above. If the script raises, fix the content: the lint message names the lesson, the question and the broken rule.

- [ ] **Step 4: Update the LearningEngine content-total test**

In `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, rename `test_importPackage_realYDSPackage_imports127ItemsAnd63QuestionsAcrossFourUnits` to `test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion` (the counts move inside the body, so later unit tasks change numbers, not names) and replace its first block of assertions with:

```swift
        XCTAssertEqual(package.version, 5)
        XCTAssertEqual(package.units.count, 5)
        let allLessons = package.units.flatMap(\.lessons)
        let allItems = allLessons.flatMap(\.items)
        XCTAssertEqual(allItems.count, 132)
        XCTAssertEqual(Set(allItems.map(\.id)).count, 132, "duplicate item ids found")
        XCTAssertTrue(allItems.allSatisfy { $0.content != nil })
        XCTAssertEqual(allItems.filter { $0.type == .vocabulary }.count, 120)
        XCTAssertEqual(allItems.filter { $0.type == .grammarPoint }.count, 7)
        XCTAssertEqual(allItems.filter { $0.type == .practiceSet }.count, 5)

        let allQuestions = allLessons.flatMap(\.questions)
        XCTAssertEqual(allQuestions.count, 109)
        XCTAssertEqual(Set(allQuestions.map(\.id)).count, 109, "duplicate question ids found")
```

Leave the rest of that test (the first-unit skill sequence, the `yds-practice-lesson-tenses` block, the reading-passage block and the mojibake sweep) exactly as it is — the free preview unit is untouched by this slice.

- [ ] **Step 5: Update `RealContentSeedingTests` and add the structure test**

In `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, rename `test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsAll127ItemsAcrossFourUnits` to `test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsEveryItem`, change `XCTAssertEqual(package.units.count, 4)` to `5`, both `XCTAssertEqual(allItems.count, 127)` occurrences (one in each test) to `132`, `XCTAssertEqual(package.version, 4)` to `5`, and the questions assertion to `109`. The passages assertion stays `3` and the skills set stays `[.vocabulary, .grammar, .reading]`.

Then add this new test to the same file — it is the spec's real-content structure test and every later unit task updates only its two concrete lists:

```swift
    /// Structure gate for the Slice 7b grammar curriculum, read from the
    /// shipped app resource. Content correctness is the per-unit review
    /// gate's job; this asserts the mechanical contract the Ders Yolu and
    /// practice screens rely on.
    func test_bundledPackage_grammarUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        XCTAssertEqual(
            units.prefix(4).map(\.id),
            [
                "yds-vocab1-unit-business-economics",
                "yds-vocab1-unit-science-research",
                "yds-vocab1-unit-law-policy-society",
                "yds-vocab1-unit-academic-writing",
            ],
            "the four vocabulary units keep orders 0-3"
        )
        XCTAssertEqual(Array(units.dropFirst(4).map(\.id)), ["yds-grammar-unit-verbs-and-tenses"])
        XCTAssertEqual(Array(units.dropFirst(4).map(\.theme)), ["Fiil ve zaman"])

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 5)
        XCTAssertEqual(
            units[4].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-tenses-2",
                "yds-grammar-modals-1",
                "yds-grammar-modals-2",
                "yds-grammar-passive-voice-1",
                "yds-grammar-passive-voice-2",
            ]
        )

        for lesson in grammarLessons {
            XCTAssertEqual(lesson.skill, .grammar, lesson.id)
            XCTAssertNil(lesson.passage, "\(lesson.id) must not carry a passage")
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .grammarPoint, lesson.id)
            XCTAssertEqual(
                card.id,
                "yds-grammar-card-" + String(lesson.id.dropFirst("yds-grammar-".count)),
                lesson.id
            )
            XCTAssertFalse(
                (card.content?.explanationTR ?? "").isEmpty,
                "\(lesson.id) card has an empty explanationTR"
            )
            let isFirstLesson = lesson.id.hasSuffix("-1")
            XCTAssertEqual(lesson.questions.count, isFirstLesson ? 8 : 10, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, isFirstLesson ? 8 : 10, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, .grammar, question.id)
                XCTAssertEqual(question.options.count, 5, question.id)
                XCTAssertTrue((0...4).contains(question.correctIndex), question.id)
                XCTAssertFalse(question.explanationTR.isEmpty, question.id)
                XCTAssertNil(question.passage, question.id)
            }
        }
    }
```

- [ ] **Step 6: Add the preview-access test**

In `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`, add next to the existing real-content tests (it reuses that file's `makeRealContentContext()` and `FixedAccessProvider`):

```swift
    /// Spec "Free preview: the new units are locked." The grammar units sit
    /// after the vocabulary units, so LessonAccessPolicy (only the
    /// lowest-ordered unit is free) keeps every one of them behind the
    /// package — while the free unit keeps its 3 vocabulary + 7 practice
    /// lessons.
    @MainActor
    func test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked() throws {
        let context = try makeRealContentContext()
        let viewModel = CoursePathViewModel(
            context: context, userID: "u", accessProvider: FixedAccessProvider(level: .preview)
        )
        viewModel.load()

        XCTAssertEqual(viewModel.sections.count, 5)
        XCTAssertEqual(viewModel.sections.last?.unitID, "yds-grammar-unit-verbs-and-tenses")
        XCTAssertEqual(viewModel.sections.last?.tasks.count, 5)

        let firstSection = try XCTUnwrap(viewModel.sections.first)
        XCTAssertEqual(firstSection.tasks.count, 10)
        XCTAssertFalse(
            firstSection.tasks.contains { if case .locked = $0 { return true } else { return false } },
            "the free unit keeps its 3 vocabulary and 7 practice lessons unlocked"
        )
        for section in viewModel.sections.dropFirst() {
            XCTAssertTrue(
                section.tasks.allSatisfy { if case .locked = $0 { return true } else { return false } },
                "\(section.unitID) must be locked for a preview user"
            )
        }
    }
```

- [ ] **Step 7: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Fiil ve zaman grammar unit with 46 questions, package version 5

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 8: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Both must end green before the task is done. If a planner test (`TodayPlanCoordinatorTests`) turns red, do **not** weaken its assertion: those tests run with `.preview` access, so a red there means the new units leaked into the free preview — fix the unit order instead.

---

## Task 3: Independent review — unit "Fiil ve zaman"

**Files:**
- Modify (only where defects are found): the five files under `content/yds-academic-vocab-1/grammar/verbs-and-tenses/`, then regenerate both derived JSON documents.

**Interfaces:**
- Consumes: Task 2's 46 questions and 5 cards.
- Produces: no code surface — a corrected question bank plus a written verdict (`ok` / `fix` / `replace` counts and every defect with its resolution).

**Whoever performs this task must not have authored Task 2.** Under subagent-driven execution, dispatch a fresh subagent with no Task 2 context; under inline execution this is the human's gate.

- [ ] **Step 1: Read the content cold**

Read the five files under `content/yds-academic-vocab-1/grammar/verbs-and-tenses/` and the spec's "Content quality rules". Do **not** read Task 2's exemplars or topic scopes first — judge each question on its own, then check coverage against the scope list at the end.

- [ ] **Step 2: Solve every question before looking at any key**

For each of the 46 questions: read the stem and the five options, decide your answer, write it down, and only then compare with `correctIndex`. A disagreement you still hold after re-reading is a `replace`.

- [ ] **Step 3: Score every question against the checklist**

Record `ok`, `fix` or `replace` on each point, with a one-line reason for anything not `ok`:

1. **Key is correct** (your cold answer matches `correctIndex`). Disagreement is a `replace`.
2. **Exactly one defensible option.** Try to argue each distractor into correctness. If you succeed for any, it is a `fix` (rewrite the distractor or tighten the stem).
3. **Distractors are plausible.** Any option obviously wrong at a glance, ungrammatical as a word form, or noticeably longer/shorter than the others is a `fix`.
4. **The stem forces the tested point.** If a second reading of the sentence makes another tense/modal/voice equally natural, it is a `fix`.
5. **`explanationTR` explains why:** states the rule *and* names and refutes at least two specific distractors. A bare restatement is a `fix`.
6. **Register and typography:** B2-C1 academic English, exactly one `----`, real Turkish characters, informal "sen" wherever a second person appears.
7. **Key distribution** per file: no key over 40% of that file's questions, no three consecutive identical keys (the lint enforces this — confirm it was not gamed by shuffling only the last question).
8. **Topic independence:** no question answerable only by a rule stated in a different topic's card (check the plan's "Topic boundaries" table).

Also review the five cards: is each rule stated correctly, is every English example grammatical, does the card actually cover every rule its own questions test, and for the lesson-2 cards is the named trap one a real YDS candidate falls into?

- [ ] **Step 4: Apply fixes at the source, never in the derived JSON**

Edit only files under `content/yds-academic-vocab-1/grammar/verbs-and-tenses/`, then regenerate:

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Both derived files must appear as modified if you changed anything. If you changed a key, re-check that file's key distribution — the lint will reject a bad one.

- [ ] **Step 5: Stop and escalate if the bank is failing systemically**

If more than five questions in this unit need `replace`, stop: do not patch. Report the verdict and re-open Task 2 for a rewrite of the unit.

- [ ] **Step 6: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Fiil ve zaman grammar unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push, confirm both CI workflows green, and record the verdict**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Then report: questions reviewed (46), counts of `ok` / `fix` / `replace`, and every defect with its resolution.

---

## Task 4: Unit "Cümle yapıları" — 7 lessons, 64 questions

**Files:**
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/conditionals-2.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/relative-clauses-1.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/relative-clauses-2.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/noun-clauses-1.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/noun-clauses-2.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/reported-speech-1.json`
- Create: `content/yds-academic-vocab-1/grammar/sentence-structures/reported-speech-2.json`
- Modify: `scripts/assemble-content.py` (`GRAMMAR_UNITS` second entry)
- Regenerate: both derived JSON documents
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's lint, Task 2's `GRAMMAR_UNITS` table and the two Swift tests it added.
- Produces: unit `yds-grammar-unit-sentence-structures` at order 5 with lesson ids `yds-grammar-conditionals-2`, `yds-grammar-relative-clauses-1/-2`, `yds-grammar-noun-clauses-1/-2`, `yds-grammar-reported-speech-1/-2`.

### Lesson inventory (contractual)

| order | file | lesson id | card id | title | headword | freqRank | baseDiff | min | questions |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `conditionals-2.json` | `yds-grammar-conditionals-2` | `yds-grammar-card-conditionals-2` | `Koşul Cümleleri: Tuzaklar` | `Conditionals (Traps)` | 2005 | 0.6 | 10 | 10 |
| 1 | `relative-clauses-1.json` | `yds-grammar-relative-clauses-1` | `yds-grammar-card-relative-clauses-1` | `Sıfat Cümlecikleri (Relative Clauses)` | `Relative Clauses` | 2006 | 0.5 | 8 | 8 |
| 2 | `relative-clauses-2.json` | `yds-grammar-relative-clauses-2` | `yds-grammar-card-relative-clauses-2` | `Sıfat Cümlecikleri: Tuzaklar` | `Relative Clauses (Traps)` | 2007 | 0.6 | 10 | 10 |
| 3 | `noun-clauses-1.json` | `yds-grammar-noun-clauses-1` | `yds-grammar-card-noun-clauses-1` | `İsim Cümlecikleri (Noun Clauses)` | `Noun Clauses` | 2008 | 0.5 | 8 | 8 |
| 4 | `noun-clauses-2.json` | `yds-grammar-noun-clauses-2` | `yds-grammar-card-noun-clauses-2` | `İsim Cümlecikleri: Tuzaklar` | `Noun Clauses (Traps)` | 2009 | 0.6 | 10 | 10 |
| 5 | `reported-speech-1.json` | `yds-grammar-reported-speech-1` | `yds-grammar-card-reported-speech-1` | `Dolaylı Anlatım (Reported Speech)` | `Reported Speech` | 2010 | 0.5 | 8 | 8 |
| 6 | `reported-speech-2.json` | `yds-grammar-reported-speech-2` | `yds-grammar-card-reported-speech-2` | `Dolaylı Anlatım: Tuzaklar` | `Reported Speech (Traps)` | 2011 | 0.6 | 10 | 10 |

Question ids follow `<lesson id>-qNN`, `q01`-`q08` for every `-1` lesson and `q01`-`q10` for every `-2` lesson. 64 questions total.

### Per-lesson topic scope

**`yds-grammar-conditionals-2` — Koşul Cümleleri: Tuzaklar (10).** Lesson 1 shipped as 7a's `yds-practice-lesson-conditionals`:
- mixed conditionals in both directions: `If she had taken the post, she would be running the department now` and `If he were more cautious, he would not have signed`.
- conditional inversion: `Had the board acted sooner, ...`, `Were the scheme to fail, ...`, `Should any delay occur, ...` (no `if`).
- `unless` = `if not`, and why `unless` cannot appear with a second negative.
- `but for + noun` / `if it had not been for` / `were it not for`.
- `otherwise`, `or else` as the consequence of a missing condition.
- `provided (that)`, `as long as`, `on condition that`, `in case` (precaution, not condition), `even if` vs `even though`.
- the recurring trap: `would` inside the `if` clause.
- boundary: no `wish` / `if only` / `it is high time` items — those belong to `yds-grammar-subjunctive-*`.

**`yds-grammar-relative-clauses-1` — Sıfat Cümlecikleri (8).**
- defining vs non-defining clauses and the comma rule; `that` is impossible in a non-defining clause.
- `who` / `whom` / `which` / `that` / `whose` selection.
- omission of the object relative pronoun.
- relative adverbs `where`, `when`, `why` and the `the reason why` / `the place where` pattern.
- subject-verb agreement inside the clause (`the policies that have`, `the policy that has`).

**`yds-grammar-relative-clauses-2` — Sıfat Cümlecikleri: Tuzaklar (10).**
- preposition + relative pronoun in formal register: `the extent to which`, `the degree to which`, `the speed at which`, `the manner in which`, `in which case`, `at which point`.
- quantifier + `of which` / `of whom`: `most of which`, `both of whom`, `the majority of which`, `none of which`.
- `whereby`.
- reduced relative clauses, active and passive: `the committee overseeing the reform`, `the measures introduced last year`.
- sentential `which` referring back to a whole clause.
- `one of the + plural + who/that + plural verb` agreement.
- the trap: `that` after a preposition, and `whose` vs `of which` for inanimate nouns.

**`yds-grammar-noun-clauses-1` — İsim Cümlecikleri (8).**
- `that`-clause as subject and as object; omission of `that` after common verbs.
- wh- noun clauses keep STATEMENT word order (`what the results mean`, not `what do the results mean`).
- `whether` vs `if`, and why only `whether` follows a preposition or precedes `to + V1`.
- noun clause after a preposition (`depends on whether`, `no indication of how`).
- `The fact that ...` as a subject.

**`yds-grammar-noun-clauses-2` — İsim Cümlecikleri: Tuzaklar (10).**
- `what` vs `that` vs `which`: `What the report ignores is ...` (missing element) vs `That the report ignores X is ...` (complete clause).
- `-ever` forms: `whatever`, `whoever`, `whichever`, `however + adjective` (= no matter how).
- verb agreement with a noun-clause subject (`What matters most is the timing`).
- anticipatory `it`: `It is widely accepted that ...`, `It remains unclear whether ...`.
- `whether or not`, and `whether ... or`.
- `the reason is that` (not `because`), `the question is whether`.
- embedded questions after `I wonder`, `no indication`, `it is unclear`.
- boundary: no backshift items — that is `yds-grammar-reported-speech-*`.

**`yds-grammar-reported-speech-1` — Dolaylı Anlatım (8).**
- backshift of tenses one step back; pronoun, time and place shifts (`yesterday` → `the day before`, `next week` → `the following week`, `here` → `there`).
- reported questions: statement word order, `if`/`whether` for yes-no questions.
- reported commands and requests: `told somebody to`, `asked somebody not to`.
- `say` vs `tell` complementation (`told the committee`, `said to the committee`).

**`yds-grammar-reported-speech-2` — Dolaylı Anlatım: Tuzaklar (10).**
- no backshift for still-true statements, scientific facts, and `must` / `might` / `could` / `should` / `ought to` / `would`.
- reporting-verb patterns: `admit + V-ing`, `deny + V-ing`, `accuse somebody of + V-ing`, `blame somebody for`, `congratulate somebody on`, `warn somebody against + V-ing`, `refuse to`, `threaten to`, `advise somebody to`, `apologise for`, `insist on + V-ing`, `object to + V-ing`.
- conditionals inside reported speech.
- `would` staying `would`; `had to` as the reported form of `must` (obligation).
- the trap: choosing a reporting verb whose pattern does not fit the complement given in the stem.
- boundary: no `suggest / demand / recommend + that + base form` items — the bare subjunctive belongs to `yds-grammar-subjunctive-*`.

### Worked exemplars (ready to ship)

**`yds-grammar-relative-clauses-2-q01`**

```json
{
  "id": "yds-grammar-relative-clauses-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The report identifies several structural weaknesses, the most serious of ---- is the steady decline in public investment.",
  "options": [
    "them",
    "which",
    "that",
    "whose",
    "what"
  ],
  "correctIndex": 1,
  "explanationTR": "«niceleyici + of + ilgi zamiri» kalıbında, iki cümleyi bağlayan bir ilgi zamiri gerekir ve cansız bir ada gönderme yapıldığı için which kullanılır: the most serious of which is ... (A) them bir zamirdir, bağlaç görevi görmez; onunla cümle iki bağımsız cümleye bölünür ve noktalama bozulur. (C) that edattan veya niceleyiciden sonra kullanılamaz. (D) whose'un ardından bir ad gelmelidir, (E) what ise daha önce geçen bir ada gönderme yapamaz.",
  "passageID": null
}
```

**`yds-grammar-noun-clauses-2-q01`**

```json
{
  "id": "yds-grammar-noun-clauses-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "---- the planners failed to anticipate was that the new line would shift congestion rather than remove it.",
  "options": [
    "That",
    "What",
    "Which",
    "Whether",
    "It"
  ],
  "correctIndex": 1,
  "explanationTR": "«failed to anticipate» geçişli bir yapıdır ve nesnesi eksiktir; eksik öğeyi içinde taşıyan ve cümleye özne olan tek bağlaç what'tır. (A) That yalnızca ÖĞESİ TAM bir cümlenin başına gelir; burada nesne eksik olduğu için olmaz. (C) Which daha önce geçmiş bir ada gönderme yapar, oysa cümlenin başındayız. (D) Whether «olup olmadığı» anlamı katar ve cümlenin geri kalanıyla uyuşmaz, (E) It ise bir yan cümle başlatamaz.",
  "passageID": null
}
```

**`yds-grammar-reported-speech-1-q01`**

```json
{
  "id": "yds-grammar-reported-speech-1-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The minister told reporters that the emergency tax ---- in force until the end of the following year.",
  "options": [
    "will remain",
    "would remain",
    "remains",
    "has remained",
    "is remaining"
  ],
  "correctIndex": 1,
  "explanationTR": "Ana cümlenin fiili «told» geçmiş zamandadır, bu yüzden yan cümlede zaman bir adım geriye kayar ve will → would olur; «the following year» ifadesi de aktarımın geçmişten yapıldığını doğrular. (A) will remain kaydırma yapılmamış doğrudan anlatım biçimidir. (C) ve (D) şu ana bağlanır, oysa cümlede «the following year» var. (E) ise remain gibi durum fiillerinin almadığı sürerlik biçimidir.",
  "passageID": null
}
```

- [ ] **Step 1: Author the seven lesson files**

Write all seven files to the inventory and topic scopes above, applying every quality rule in Global Constraints, with the same card style as Task 2's `yds-grammar-card-modals-1` (bulleted Turkish rule blocks, English examples, an explicit "En sık düşülen tuzak:" paragraph in every lesson-2 card). Plan keys before writing: 8-question files use each key at most three times, 10-question files at most four times, never three in a row.

- [ ] **Step 2: Register the unit in `scripts/assemble-content.py`**

Append to `GRAMMAR_UNITS`, after the `yds-grammar-unit-verbs-and-tenses` entry:

```python
    {
        "id": "yds-grammar-unit-sentence-structures",
        "theme": "Cümle yapıları",
        "order": 5,
        "files": [
            "sentence-structures/conditionals-2.json",
            "sentence-structures/relative-clauses-1.json",
            "sentence-structures/relative-clauses-2.json",
            "sentence-structures/noun-clauses-1.json",
            "sentence-structures/noun-clauses-2.json",
            "sentence-structures/reported-speech-1.json",
            "sentence-structures/reported-speech-2.json",
        ],
    },
```

`PACKAGE_VERSION` stays 5 — one bump per slice is enough to force the reseed.

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: both derived JSON files modified. If not, you used the Store Python alias — re-run with the full path.

- [ ] **Step 4: Update the content-total assertions**

`LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, in `test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion`: `package.units.count` → `6`, `allItems.count` → `139` (both the count and the `Set(...)` uniqueness assertion), `grammarPoint` count → `14`, `allQuestions.count` → `173` (both assertions). `vocabulary` stays 120, `practiceSet` stays 5, `package.version` stays 5.

`App/Tests/EnglishAppTests/RealContentSeedingTests.swift`: `package.units.count` → `6`, both `allItems.count` → `139`, questions → `173`; passages stay `3`. In `test_bundledPackage_grammarUnits_areStructurallySound`, extend the two grammar-unit lists and the lesson count:

```swift
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.id)),
            ["yds-grammar-unit-verbs-and-tenses", "yds-grammar-unit-sentence-structures"]
        )
        XCTAssertEqual(Array(units.dropFirst(4).map(\.theme)), ["Fiil ve zaman", "Cümle yapıları"])

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 12)
```

and add, after the existing `units[4].lessons` assertion:

```swift
        XCTAssertEqual(
            units[5].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-conditionals-2",
                "yds-grammar-relative-clauses-1",
                "yds-grammar-relative-clauses-2",
                "yds-grammar-noun-clauses-1",
                "yds-grammar-noun-clauses-2",
                "yds-grammar-reported-speech-1",
                "yds-grammar-reported-speech-2",
            ]
        )
```

`App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`, in `test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked`: `sections.count` → `6`, `sections.last?.unitID` → `"yds-grammar-unit-sentence-structures"`, `sections.last?.tasks.count` → `7`.

- [ ] **Step 5: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Cümle yapıları grammar unit with 64 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 5: Independent review — unit "Cümle yapıları"

**Files:**
- Modify (only where defects are found): the seven files under `content/yds-academic-vocab-1/grammar/sentence-structures/`, then regenerate both derived JSON documents.

**Interfaces:**
- Consumes: Task 4's 64 questions and 7 cards.
- Produces: a corrected question bank plus a written verdict.

**Whoever performs this task must not have authored Task 4** — dispatch a fresh subagent with no Task 4 context.

- [ ] **Step 1: Read the content cold**

Read the seven files under `content/yds-academic-vocab-1/grammar/sentence-structures/` and the spec's "Content quality rules". Do not read Task 4's exemplars first.

- [ ] **Step 2: Solve every question before looking at any key**

For each of the 64 questions: decide your answer from the stem and options alone, write it down, then compare with `correctIndex`. A disagreement you still hold after re-reading is a `replace`.

- [ ] **Step 3: Score every question against the checklist**

Record `ok`, `fix` or `replace` per point, with a one-line reason for anything not `ok`:

1. **Key is correct** (cold answer matches `correctIndex`); disagreement is a `replace`.
2. **Exactly one defensible option** — argue each distractor into correctness; any success is a `fix`.
3. **Distractors are plausible** — nothing obviously wrong at a glance, no length or register cue.
4. **The stem forces the tested point** — no second reading makes another option equally natural.
5. **`explanationTR` explains why** — rule plus at least two named distractors refuted.
6. **Register and typography** — B2-C1 academic English, exactly one `----`, real Turkish characters, informal "sen".
7. **Key distribution** per file — no key over 40%, no three consecutive identical keys.
8. **Topic independence** — check the plan's "Topic boundaries" table. In this unit specifically: no `wish` / `if only` / `it's high time` in Conditionals, no backshift items in Noun Clauses, no `suggest/demand + that + base` in Reported Speech.

Also review the seven cards: rules correct, English examples grammatical, card covers every rule its own questions test, lesson-2 traps real.

- [ ] **Step 4: Apply fixes at the source, never in the derived JSON**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

- [ ] **Step 5: Stop and escalate if the bank is failing systemically**

More than five `replace` verdicts in this unit means the unit is rewritten, not patched: report and re-open Task 4.

- [ ] **Step 6: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Cümle yapıları grammar unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push, confirm both CI workflows green, and record the verdict**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Report: 64 questions reviewed, `ok` / `fix` / `replace` counts, every defect with its resolution.

---

## Task 6: Unit "Fiilimsiler ve bağlantılar" — 6 lessons, 54 questions

**Files:**
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/gerunds-infinitives-1.json`
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/gerunds-infinitives-2.json`
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/participle-clauses-1.json`
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/participle-clauses-2.json`
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/conjunctions-linkers-1.json`
- Create: `content/yds-academic-vocab-1/grammar/verbals-and-linkers/conjunctions-linkers-2.json`
- Modify: `scripts/assemble-content.py` (`GRAMMAR_UNITS` third entry)
- Regenerate: both derived JSON documents
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's lint and the `GRAMMAR_UNITS` table.
- Produces: unit `yds-grammar-unit-verbals-and-linkers` at order 6 with lesson ids `yds-grammar-gerunds-infinitives-1/-2`, `yds-grammar-participle-clauses-1/-2`, `yds-grammar-conjunctions-linkers-1/-2`.

### Lesson inventory (contractual)

| order | file | lesson id | card id | title | headword | freqRank | baseDiff | min | questions |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `gerunds-infinitives-1.json` | `yds-grammar-gerunds-infinitives-1` | `yds-grammar-card-gerunds-infinitives-1` | `İsim-Fiiller ve Mastarlar (Gerunds & Infinitives)` | `Gerunds & Infinitives` | 2012 | 0.5 | 8 | 8 |
| 1 | `gerunds-infinitives-2.json` | `yds-grammar-gerunds-infinitives-2` | `yds-grammar-card-gerunds-infinitives-2` | `İsim-Fiiller ve Mastarlar: Tuzaklar` | `Gerunds & Infinitives (Traps)` | 2013 | 0.6 | 10 | 10 |
| 2 | `participle-clauses-1.json` | `yds-grammar-participle-clauses-1` | `yds-grammar-card-participle-clauses-1` | `Ortaç Cümlecikleri (Participle Clauses)` | `Participle Clauses` | 2014 | 0.5 | 8 | 8 |
| 3 | `participle-clauses-2.json` | `yds-grammar-participle-clauses-2` | `yds-grammar-card-participle-clauses-2` | `Ortaç Cümlecikleri: Tuzaklar` | `Participle Clauses (Traps)` | 2015 | 0.6 | 10 | 10 |
| 4 | `conjunctions-linkers-1.json` | `yds-grammar-conjunctions-linkers-1` | `yds-grammar-card-conjunctions-linkers-1` | `Bağlaçlar ve Bağlayıcılar (Conjunctions & Linkers)` | `Conjunctions & Linkers` | 2016 | 0.5 | 8 | 8 |
| 5 | `conjunctions-linkers-2.json` | `yds-grammar-conjunctions-linkers-2` | `yds-grammar-card-conjunctions-linkers-2` | `Bağlaçlar ve Bağlayıcılar: Tuzaklar` | `Conjunctions & Linkers (Traps)` | 2017 | 0.6 | 10 | 10 |

54 questions total.

### Per-lesson topic scope

**`yds-grammar-gerunds-infinitives-1` (8).**
- verb + gerund: `avoid`, `deny`, `mind`, `risk`, `consider`, `postpone`, `involve`, `justify`.
- verb + infinitive: `decide`, `manage`, `afford`, `refuse`, `hope`, `agree`, `fail`, `tend`.
- verb + object + infinitive: `allow`, `persuade`, `enable`, `encourage`, `require`, `expect`.
- preposition + gerund: `capable of doing`, `responsible for doing`, `succeed in doing`.
- `to` as a preposition: `look forward to doing`, `object to doing`, `be accustomed to doing`, `be committed to doing`.
- bare infinitive after `make`, `let`, and both forms after `help`.

**`yds-grammar-gerunds-infinitives-2` (10).**
- meaning-changing verbs: `remember`, `forget`, `regret`, `stop`, `try`, `go on`, `mean`, `come` + gerund vs infinitive.
- `need + V-ing` with passive meaning (`The data need checking`) vs `need to be checked`.
- perfect forms: `having done`, `to have done`, and their passives `having been done`, `to have been done`.
- passive verbals: `being criticised`, `to be criticised`.
- adjective + infinitive; `too ... to` vs `... enough to`.
- bare infinitive after `rather than`, `but`, `except`.
- `used to + V1` vs `be used to + V-ing` (the form contrast only; tense use is Tenses' topic).
- the trap: a verb whose pattern the learner half-remembers (`suggest doing`, not `suggest to do`; `look forward to doing`, not `to do`).

**`yds-grammar-participle-clauses-1` (8).**
- present participle for an active, simultaneous or causal clause: `Working under severe constraints, the team ...`.
- past participle for a passive one: `Published in 1996, the study ...`.
- perfect participle for a completed earlier action: `Having completed the survey, the researchers ...`.
- reduced relative clauses, active and passive.
- the subject rule: the participle's implied subject is the main clause's subject.

**`yds-grammar-participle-clauses-2` (10).**
- conjunction retained before the participle: `While working ...`, `When asked ...`, `Although criticised ...`, `Once approved ...`, `Before submitting ...`.
- absolute constructions: `The weather being unusually mild, ...`, `All things considered, ...`, `Other things being equal, ...`, `Its funding withdrawn, the project ...`.
- `With + noun + participle`: `With inflation rising sharply, ...`.
- participial prepositions: `Given ...`, `Provided ...`, `Considering ...`, `Judging by ...`, `Assuming ...`.
- `having done` vs `having been done`.
- the dangling-participle trap: an option whose implied subject is not the main-clause subject is always wrong.

**`yds-grammar-conjunctions-linkers-1` (8).**
- coordinating conjunctions: `and`, `but`, `or`, `so`, `yet`, `for`.
- cause: `because`, `since`, `as`; result: `so ... that`, `such ... that`.
- contrast: `although`, `though`, `even though`, `while`, `whereas`.
- purpose: `so that`, `in order that`, `so as to`, `in order to`.
- time: `when`, `while`, `as soon as`, `until`, `by the time`.
- structural contrast: `although + clause` vs `despite / in spite of + noun or V-ing`.

**`yds-grammar-conjunctions-linkers-2` (10).**
- three-way contrast: conjunction (`because`, `although`) vs connector (`however`, `nevertheless`, `therefore`, `thus`, `moreover`, `consequently`) vs preposition (`despite`, `owing to`, `due to`, `on account of`, `in view of`).
- paired conjunctions and their agreement: `not only ... but also`, `either ... or`, `neither ... nor`, `both ... and` (verb agrees with the nearer subject except after `both ... and`).
- `lest`, `in case`, `unless`, `otherwise`, `whereas`.
- `no matter how / however + adjective + subject + verb`.
- punctuation: a connector cannot join two clauses with only a comma.
- the trap: `due to` (follows a noun/linking verb) vs `because of` (modifies a verb).
- boundary: `not only ... but also` appears here WITHOUT inversion; the inverted form is `yds-grammar-inversion-*`.

### Worked exemplars (ready to ship)

**`yds-grammar-gerunds-infinitives-2-q01`**

```json
{
  "id": "yds-grammar-gerunds-infinitives-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The engineers now regret ---- the early warning signs, a decision that eventually cost the company millions.",
  "options": [
    "to ignore",
    "ignoring",
    "to be ignored",
    "being ignored",
    "to have ignored being"
  ],
  "correctIndex": 1,
  "explanationTR": "«regret + V-ing» geçmişte yapılmış bir eylemden pişmanlık duymayı anlatır; cümledeki «a decision that eventually cost ...» bu eylemin çoktan olduğunu gösteriyor. (A) «regret to + fiil» yalnızca kötü bir haber verirken kullanılır (regret to inform you) ve burada anlamsızdır. (C) ve (D) edilgendir; mühendisler işaretleri görmezden gelen taraftır, görmezden gelinen değil. (E) ise dilbilgisel olarak kurulmuş bir yapı değildir.",
  "passageID": null
}
```

**`yds-grammar-participle-clauses-2-q01`**

```json
{
  "id": "yds-grammar-participle-clauses-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "---- in the early 1960s, the bridge now carries three times the traffic volume it was designed for.",
  "options": [
    "Constructing",
    "Having constructed",
    "Constructed",
    "Being constructed",
    "To construct"
  ],
  "correctIndex": 2,
  "explanationTR": "Ortaç cümleciğinin gizli öznesi ana cümlenin öznesidir: the bridge. Köprü inşa EDİLEN taraf olduğu için edilgen anlam veren üçüncü hâl (past participle) gerekir: Constructed in the early 1960s = As it was constructed ... (A) ve (B) etkendir, yani köprünün bir şey inşa ettiğini söyler. (D) Being constructed şu anda sürmekte olan bir edilgen eylemi anlatır ve «in the early 1960s» ile çelişir. (E) mastar ise amaç bildirir, zaman değil.",
  "passageID": null
}
```

**`yds-grammar-conjunctions-linkers-2-q01`**

```json
{
  "id": "yds-grammar-conjunctions-linkers-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "---- the sharp rise in enrolment, the university has not increased the number of teaching staff for three years.",
  "options": [
    "Although",
    "Despite",
    "However",
    "Whereas",
    "Even though"
  ],
  "correctIndex": 1,
  "explanationTR": "Boşluktan sonra yan cümle değil, bir AD ÖBEĞİ var (the sharp rise in enrolment); ad öbeğinin önüne yalnızca edat niteliği taşıyan despite / in spite of gelir. (A), (D) ve (E) bağlaçtır ve ardından özne + fiil ister. (C) however ise cümle bağlayıcıdır; iki cümle arasında noktalı virgülle ya da yeni cümlenin başında kullanılır, bir ad öbeğinin önünde kullanılamaz.",
  "passageID": null
}
```

- [ ] **Step 1: Author the six lesson files**

Write all six to the inventory and topic scopes above, applying every quality rule in Global Constraints, with the card style established in Task 2. Plan keys before writing: 8-question files use each key at most three times, 10-question files at most four, never three in a row.

- [ ] **Step 2: Register the unit in `scripts/assemble-content.py`**

Append to `GRAMMAR_UNITS`, after the `yds-grammar-unit-sentence-structures` entry:

```python
    {
        "id": "yds-grammar-unit-verbals-and-linkers",
        "theme": "Fiilimsiler ve bağlantılar",
        "order": 6,
        "files": [
            "verbals-and-linkers/gerunds-infinitives-1.json",
            "verbals-and-linkers/gerunds-infinitives-2.json",
            "verbals-and-linkers/participle-clauses-1.json",
            "verbals-and-linkers/participle-clauses-2.json",
            "verbals-and-linkers/conjunctions-linkers-1.json",
            "verbals-and-linkers/conjunctions-linkers-2.json",
        ],
    },
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: both derived JSON files modified.

- [ ] **Step 4: Update the content-total assertions**

`ContentImporterTests.swift`: `package.units.count` → `7`, `allItems.count` → `145` (count and uniqueness), `grammarPoint` → `20`, `allQuestions.count` → `227` (count and uniqueness).

`RealContentSeedingTests.swift`: `package.units.count` → `7`, both `allItems.count` → `145`, questions → `227`. In the structure test:

```swift
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.id)),
            [
                "yds-grammar-unit-verbs-and-tenses",
                "yds-grammar-unit-sentence-structures",
                "yds-grammar-unit-verbals-and-linkers",
            ]
        )
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.theme)),
            ["Fiil ve zaman", "Cümle yapıları", "Fiilimsiler ve bağlantılar"]
        )

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 18)
```

and add after the `units[5].lessons` assertion:

```swift
        XCTAssertEqual(
            units[6].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-gerunds-infinitives-1",
                "yds-grammar-gerunds-infinitives-2",
                "yds-grammar-participle-clauses-1",
                "yds-grammar-participle-clauses-2",
                "yds-grammar-conjunctions-linkers-1",
                "yds-grammar-conjunctions-linkers-2",
            ]
        )
```

`CoursePathViewModelTests.swift`: `sections.count` → `7`, `sections.last?.unitID` → `"yds-grammar-unit-verbals-and-linkers"`, `sections.last?.tasks.count` → `6`.

- [ ] **Step 5: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Fiilimsiler ve bağlantılar grammar unit with 54 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 7: Independent review — unit "Fiilimsiler ve bağlantılar"

**Files:**
- Modify (only where defects are found): the six files under `content/yds-academic-vocab-1/grammar/verbals-and-linkers/`, then regenerate both derived JSON documents.

**Interfaces:**
- Consumes: Task 6's 54 questions and 6 cards.
- Produces: a corrected question bank plus a written verdict.

**Whoever performs this task must not have authored Task 6** — dispatch a fresh subagent with no Task 6 context.

- [ ] **Step 1: Read the content cold**

Read the six files under `content/yds-academic-vocab-1/grammar/verbals-and-linkers/` and the spec's "Content quality rules". Do not read Task 6's exemplars first.

- [ ] **Step 2: Solve every question before looking at any key**

Answer all 54 from stem and options alone, write your answers down, then compare with `correctIndex`.

- [ ] **Step 3: Score every question against the checklist**

Record `ok`, `fix` or `replace` per point, with a one-line reason for anything not `ok`:

1. **Key is correct** (cold answer matches `correctIndex`); disagreement is a `replace`.
2. **Exactly one defensible option** — argue each distractor into correctness; any success is a `fix`.
3. **Distractors are plausible** — nothing obviously wrong at a glance, no length or register cue.
4. **The stem forces the tested point.**
5. **`explanationTR` explains why** — rule plus at least two named distractors refuted.
6. **Register and typography** — B2-C1 academic English, exactly one `----`, real Turkish characters, informal "sen".
7. **Key distribution** per file — no key over 40%, no three consecutive identical keys.
8. **Topic independence** — check the plan's "Topic boundaries" table. In this unit specifically: participle items must not reduce to a verb-pattern question, and `not only ... but also` must appear WITHOUT inversion (inversion belongs to unit 4).

In this unit also verify, question by question, that every participle question's implied subject really is the main-clause subject — a dangling participle in a *key* is a `replace`.

Also review the six cards: rules correct, English examples grammatical, card covers every rule its own questions test, lesson-2 traps real.

- [ ] **Step 4: Apply fixes at the source, never in the derived JSON**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

- [ ] **Step 5: Stop and escalate if the bank is failing systemically**

More than five `replace` verdicts in this unit means the unit is rewritten, not patched: report and re-open Task 6.

- [ ] **Step 6: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Fiilimsiler ve bağlantılar grammar unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push, confirm both CI workflows green, and record the verdict**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Report: 54 questions reviewed, `ok` / `fix` / `replace` counts, every defect with its resolution.

---

## Task 8: Unit "Sınav düzeyi yapılar" — 4 lessons, 36 questions

**Files:**
- Create: `content/yds-academic-vocab-1/grammar/exam-level-structures/inversion-1.json`
- Create: `content/yds-academic-vocab-1/grammar/exam-level-structures/inversion-2.json`
- Create: `content/yds-academic-vocab-1/grammar/exam-level-structures/subjunctive-1.json`
- Create: `content/yds-academic-vocab-1/grammar/exam-level-structures/subjunctive-2.json`
- Modify: `scripts/assemble-content.py` (`GRAMMAR_UNITS` fourth entry)
- Regenerate: both derived JSON documents
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's lint and the `GRAMMAR_UNITS` table.
- Produces: unit `yds-grammar-unit-exam-level-structures` at order 7 with lesson ids `yds-grammar-inversion-1/-2`, `yds-grammar-subjunctive-1/-2`.

### Lesson inventory (contractual)

| order | file | lesson id | card id | title | headword | freqRank | baseDiff | min | questions |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `inversion-1.json` | `yds-grammar-inversion-1` | `yds-grammar-card-inversion-1` | `Devrik Yapı ve Vurgu (Inversion & Emphasis)` | `Inversion & Emphasis` | 2018 | 0.5 | 8 | 8 |
| 1 | `inversion-2.json` | `yds-grammar-inversion-2` | `yds-grammar-card-inversion-2` | `Devrik Yapı ve Vurgu: Tuzaklar` | `Inversion & Emphasis (Traps)` | 2019 | 0.6 | 10 | 10 |
| 2 | `subjunctive-1.json` | `yds-grammar-subjunctive-1` | `yds-grammar-card-subjunctive-1` | `İstek Kipi (Subjunctive)` | `Subjunctive` | 2020 | 0.5 | 8 | 8 |
| 3 | `subjunctive-2.json` | `yds-grammar-subjunctive-2` | `yds-grammar-card-subjunctive-2` | `İstek Kipi: Tuzaklar` | `Subjunctive (Traps)` | 2021 | 0.6 | 10 | 10 |

36 questions total.

### Per-lesson topic scope

**`yds-grammar-inversion-1` (8).**
- the mechanism: a fronted negative or restrictive adverbial forces question word order in the clause that follows (`did the board realise`, `has the ministry published`).
- fronted negative adverbials: `Never`, `Rarely`, `Seldom`, `Little`, `At no time`, `Under no circumstances`, `On no account`, `Not until`, `Nowhere`.
- `Hardly / Scarcely had ... when`, `No sooner had ... than` (the inversion; the tense pairing is Tenses').
- `Only after / Only when / Only by / Only if / Only then` + inverted MAIN clause.
- `Not only ... but also` with inversion in the first clause.
- placement: after `Only when the audit was complete` the inversion goes in the MAIN clause, never inside the `only` clause.

**`yds-grammar-inversion-2` (10).**
- conditional inversion: `Had + subject + V3`, `Were + subject + to V1`, `Should + subject + V1` — no `if`.
- `So + adjective + be + subject + that ...` (`So rapid was the decline that ...`), `Such + be + subject + that ...` (`Such was the outcry that ...`).
- `So do I` / `Neither does the ministry` agreement echoes.
- inversion after a fronted place adverbial with an intransitive verb: `In the corner stood ...`, `Among the findings was ...`.
- cleft sentences: `It was the funding cut that ...`, `What the committee needed was ...`, `All that remains is ...`.
- emphatic `do / does / did` + bare infinitive.
- the trap: a fronted adverbial that is NOT negative or restrictive (`Recently`, `In 2019`) takes normal word order; an inverted option there is always wrong.
- boundary: conditional MEANING (which type to use) stays in Conditionals; here the question is the inverted FORM.

**`yds-grammar-subjunctive-1` (8).**
- mandative subjunctive after `suggest`, `recommend`, `propose`, `demand`, `request`, `insist`, `urge`, `require` + `that` + bare infinitive, in every person and tense (`that he be`, `that the fee be waived`).
- the negative form: `that he not be appointed` (no `does not`).
- `It is essential / vital / imperative / crucial / necessary / advisable that + bare infinitive`.
- noun forms: `the recommendation that the post be abolished`, `on the condition that he resign`.
- the British `should + bare infinitive` variant.
- passive subjunctive: `that the report be submitted`.

**`yds-grammar-subjunctive-2` (10).**
- `wish` + past simple (present regret), + past perfect (past regret), + `would` (annoyance or a request for change).
- `if only` with the same three patterns.
- `would rather + subject + past simple / past perfect` (different subject).
- `It is (high) time + subject + past simple`.
- `as if / as though + past simple` for an unreal comparison.
- `lest + bare infinitive`.
- formal `May + subject + bare infinitive`.
- the trap: `I wish he would come` (wanting a change) vs `I wish he came` (an unreal present), and `would rather he went` vs `would rather go`.

### Worked exemplars (ready to ship)

**`yds-grammar-inversion-1-q01`**

```json
{
  "id": "yds-grammar-inversion-1-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "Not until the external audit had been completed ---- the true scale of the deficit.",
  "options": [
    "the board realised",
    "did the board realise",
    "the board did realise",
    "had the board realised",
    "realised the board"
  ],
  "correctIndex": 1,
  "explanationTR": "«Not until ...» olumsuz bir zarf öbeğiyle başlayan cümlede devrik yapı ANA cümlede kurulur: yardımcı fiil + özne + yalın fiil, yani did the board realise. (A) ve (C) düz sıralamadır; olumsuz zarfla başlayan cümlede kullanılmaz. (D) yan cümle zaten past perfect olduğu için ana cümlenin de past perfect olması zaman sıralamasını bozar. (E) ise yardımcı fiilsiz bir devriklemedir; İngilizcede bu yapı yalnızca yer zarfıyla başlayan cümlelerde görülür.",
  "passageID": null
}
```

**`yds-grammar-inversion-2-q01`**

```json
{
  "id": "yds-grammar-inversion-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "---- the government acted on the early warnings, the epidemic could have been contained within a matter of weeks.",
  "options": [
    "Should",
    "Were",
    "Had",
    "Provided",
    "Unless"
  ],
  "correctIndex": 2,
  "explanationTR": "Ana cümlede «could have been contained» var; bu, geçmişte gerçekleşmemiş bir durumu anlatır ve if'siz devrik biçimi «Had + özne + V3»tür: Had the government acted ... (A) Should ardından yalın fiil ister ve geleceğe dönük ihtimal bildirir. (B) Were ardından «to act» gerektirir ve yine geçmişi anlatamaz. (D) ve (E) bağlaçtır; devrik yapı kurmaz, üstelik onlardan sonra acted değil çekimli bir yapı beklenir.",
  "passageID": null
}
```

**`yds-grammar-subjunctive-1-q01`**

```json
{
  "id": "yds-grammar-subjunctive-1-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The auditors demanded that every transaction over ten thousand liras ---- by an independent reviewer before the accounts were signed off.",
  "options": [
    "is verified",
    "be verified",
    "was verified",
    "will be verified",
    "has been verified"
  ],
  "correctIndex": 1,
  "explanationTR": "«demand» gibi istek/emir bildiren fiillerden sonra gelen that cümleciğinde fiil çekimlenmez, yalın hâlde kalır; edilgen olduğu için be verified olur. Ana cümle geçmiş zamanda olsa bile bu yapı değişmez. (A), (C) ve (E) çekimli biçimlerdir ve istek kipini bozar. (D) will be verified ise gelecek bildirir; talep cümleciğinde will kullanılmaz.",
  "passageID": null
}
```

- [ ] **Step 1: Author the four lesson files**

Write all four to the inventory and topic scopes above, applying every quality rule in Global Constraints, with the card style established in Task 2. Plan keys before writing: 8-question files use each key at most three times, 10-question files at most four, never three in a row.

- [ ] **Step 2: Register the unit in `scripts/assemble-content.py`**

Append to `GRAMMAR_UNITS`, after the `yds-grammar-unit-verbals-and-linkers` entry:

```python
    {
        "id": "yds-grammar-unit-exam-level-structures",
        "theme": "Sınav düzeyi yapılar",
        "order": 7,
        "files": [
            "exam-level-structures/inversion-1.json",
            "exam-level-structures/inversion-2.json",
            "exam-level-structures/subjunctive-1.json",
            "exam-level-structures/subjunctive-2.json",
        ],
    },
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: both derived JSON files modified.

- [ ] **Step 4: Update the content-total assertions**

`ContentImporterTests.swift`: `package.units.count` → `8`, `allItems.count` → `149` (count and uniqueness), `grammarPoint` → `24`, `allQuestions.count` → `263` (count and uniqueness).

`RealContentSeedingTests.swift`: `package.units.count` → `8`, both `allItems.count` → `149`, questions → `263`. In the structure test:

```swift
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.id)),
            [
                "yds-grammar-unit-verbs-and-tenses",
                "yds-grammar-unit-sentence-structures",
                "yds-grammar-unit-verbals-and-linkers",
                "yds-grammar-unit-exam-level-structures",
            ]
        )
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.theme)),
            ["Fiil ve zaman", "Cümle yapıları", "Fiilimsiler ve bağlantılar", "Sınav düzeyi yapılar"]
        )

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 22)
```

and add after the `units[6].lessons` assertion:

```swift
        XCTAssertEqual(
            units[7].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-inversion-1",
                "yds-grammar-inversion-2",
                "yds-grammar-subjunctive-1",
                "yds-grammar-subjunctive-2",
            ]
        )
```

`CoursePathViewModelTests.swift`: `sections.count` → `8`, `sections.last?.unitID` → `"yds-grammar-unit-exam-level-structures"`, `sections.last?.tasks.count` → `4`.

- [ ] **Step 5: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Sınav düzeyi yapılar grammar unit with 36 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 9: Independent review — unit "Sınav düzeyi yapılar"

**Files:**
- Modify (only where defects are found): the four files under `content/yds-academic-vocab-1/grammar/exam-level-structures/`, then regenerate both derived JSON documents.

**Interfaces:**
- Consumes: Task 8's 36 questions and 4 cards.
- Produces: a corrected question bank plus a written verdict.

**Whoever performs this task must not have authored Task 8** — dispatch a fresh subagent with no Task 8 context.

- [ ] **Step 1: Read the content cold**

Read the four files under `content/yds-academic-vocab-1/grammar/exam-level-structures/` and the spec's "Content quality rules". Do not read Task 8's exemplars first.

- [ ] **Step 2: Solve every question before looking at any key**

Answer all 36 from stem and options alone, write your answers down, then compare with `correctIndex`.

- [ ] **Step 3: Score every question against the checklist**

Record `ok`, `fix` or `replace` per point, with a one-line reason for anything not `ok`:

1. **Key is correct** (cold answer matches `correctIndex`); disagreement is a `replace`.
2. **Exactly one defensible option** — argue each distractor into correctness; any success is a `fix`.
3. **Distractors are plausible** — nothing obviously wrong at a glance, no length or register cue.
4. **The stem forces the tested point.**
5. **`explanationTR` explains why** — rule plus at least two named distractors refuted.
6. **Register and typography** — B2-C1 academic English, exactly one `----`, real Turkish characters, informal "sen".
7. **Key distribution** per file — no key over 40%, no three consecutive identical keys.
8. **Topic independence** — check the plan's "Topic boundaries" table. In this unit specifically: inversion questions must test the FORM (the conditional type is Conditionals'), and subjunctive questions must not reduce to ordinary modal meaning.

This unit carries the highest risk of an inverted sentence that is merely unusual rather than required: for every inversion key, confirm the fronted element really is negative, restrictive, or a conditional trigger. An inversion keyed after a neutral adverbial is a `replace`.

Also review the four cards: rules correct, English examples grammatical, card covers every rule its own questions test, lesson-2 traps real.

- [ ] **Step 4: Apply fixes at the source, never in the derived JSON**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

- [ ] **Step 5: Stop and escalate if the bank is failing systemically**

More than five `replace` verdicts in this unit means the unit is rewritten, not patched: report and re-open Task 8.

- [ ] **Step 6: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Sınav düzeyi yapılar grammar unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push, confirm both CI workflows green, and record the verdict**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Report: 36 questions reviewed, `ok` / `fix` / `replace` counts, every defect with its resolution.

---

## Task 10: Unit "Kelime düzeyinde gramer" — 8 lessons, 72 questions

**Files:**
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/prepositions-1.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/prepositions-2.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/comparatives-1.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/comparatives-2.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/determiners-1.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/determiners-2.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/articles-1.json`
- Create: `content/yds-academic-vocab-1/grammar/word-level-grammar/articles-2.json`
- Modify: `scripts/assemble-content.py` (`GRAMMAR_UNITS` fifth entry)
- Regenerate: both derived JSON documents
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's lint and the `GRAMMAR_UNITS` table.
- Produces: unit `yds-grammar-unit-word-level-grammar` at order 8 with lesson ids `yds-grammar-prepositions-1/-2`, `yds-grammar-comparatives-1/-2`, `yds-grammar-determiners-1/-2`, `yds-grammar-articles-1/-2`. After this task the package is complete: 9 units, 49 lessons, 157 items, 335 questions.

### Lesson inventory (contractual)

| order | file | lesson id | card id | title | headword | freqRank | baseDiff | min | questions |
|---|---|---|---|---|---|---|---|---|---|
| 0 | `prepositions-1.json` | `yds-grammar-prepositions-1` | `yds-grammar-card-prepositions-1` | `Edatlar (Prepositions)` | `Prepositions` | 2022 | 0.5 | 8 | 8 |
| 1 | `prepositions-2.json` | `yds-grammar-prepositions-2` | `yds-grammar-card-prepositions-2` | `Edatlar: Tuzaklar` | `Prepositions (Traps)` | 2023 | 0.6 | 10 | 10 |
| 2 | `comparatives-1.json` | `yds-grammar-comparatives-1` | `yds-grammar-card-comparatives-1` | `Karşılaştırma Yapıları (Comparatives)` | `Comparatives` | 2024 | 0.5 | 8 | 8 |
| 3 | `comparatives-2.json` | `yds-grammar-comparatives-2` | `yds-grammar-card-comparatives-2` | `Karşılaştırma Yapıları: Tuzaklar` | `Comparatives (Traps)` | 2025 | 0.6 | 10 | 10 |
| 4 | `determiners-1.json` | `yds-grammar-determiners-1` | `yds-grammar-card-determiners-1` | `Belirteçler ve Niceleyiciler (Determiners & Quantifiers)` | `Determiners & Quantifiers` | 2026 | 0.5 | 8 | 8 |
| 5 | `determiners-2.json` | `yds-grammar-determiners-2` | `yds-grammar-card-determiners-2` | `Belirteçler ve Niceleyiciler: Tuzaklar` | `Determiners & Quantifiers (Traps)` | 2027 | 0.6 | 10 | 10 |
| 6 | `articles-1.json` | `yds-grammar-articles-1` | `yds-grammar-card-articles-1` | `Tanımlıklar (Articles)` | `Articles` | 2028 | 0.5 | 8 | 8 |
| 7 | `articles-2.json` | `yds-grammar-articles-2` | `yds-grammar-card-articles-2` | `Tanımlıklar: Tuzaklar` | `Articles (Traps)` | 2029 | 0.6 | 10 | 10 |

72 questions total.

### Per-lesson topic scope

**`yds-grammar-prepositions-1` (8).**
- time: `in` / `on` / `at`, `by` vs `until`, `for` vs `during`, `within`, `throughout`.
- place and movement: `in` / `on` / `at`, `into`, `onto`, `from ... to`, `across`, `among` vs `between`.
- verb + preposition: `depend on`, `consist of`, `result in`, `result from`, `account for`, `deal with`, `refer to`, `contribute to`, `rely on`.
- adjective + preposition: `aware of`, `responsible for`, `capable of`, `similar to`, `different from`, `subject to`, `relevant to`.
- noun + preposition: `an increase in`, `the reason for`, `an effect on`, `a solution to`, `demand for`, `an approach to`, `an attitude towards`.

**`yds-grammar-prepositions-2` (10).**
- near-miss pairs: `result in` vs `result from`, `effect on` vs `affect`, `concerned with` vs `concerned about`, `substitute for` vs `replace with`, `attribute to` vs `blame for`.
- verbs that take no preposition: `discuss`, `comprise`, `approach`, `enter`, `lack`, `emphasise` (against learner-favourite `discuss about`).
- compliance family: `comply with`, `conform to`, `adhere to`, `abide by`.
- complex prepositions: `regardless of`, `in terms of`, `in the wake of`, `at the expense of`, `in the absence of`, `on the grounds of / that`, `in accordance with`, `in response to`, `apart from`, `with a view to + V-ing`, `in line with`.
- preposition + `V-ing` after complex prepositions.
- the trap: an option that is a real collocation with a different noun/verb than the one in the stem.

**`yds-grammar-comparatives-1` (8).**
- `-er` vs `more` and the `than` clause; superlatives with `the`, `in` and `of`.
- irregular forms: `better`, `worse`, `farther / further`, `less`, `least`.
- `as ... as`, `not as / so ... as`.
- intensifiers: `much`, `far`, `considerably`, `slightly`, `a great deal` + comparative.
- `one of the + superlative + plural noun`.
- countability in comparison: `fewer` vs `less`.

**`yds-grammar-comparatives-2` (10).**
- double comparative: `The more rapidly the population grows, the greater the pressure becomes`.
- multiples: `twice as high as`, `three times the size of`, `half as expensive as`.
- `no more than` vs `not more than`, `no fewer than`, `no later than`.
- `the same as`, `similar to`, `different from`, `in contrast to`.
- `than ever before`, `than any other + singular noun`.
- parallelism in comparison: `The output of the new plant exceeds that of the old one`; `those of` for plurals.
- `prefer A to B`, `would rather A than B` (form only).
- the trap: a double marker (`more easier`, `most highest`) and a comparison of unlike things.

**`yds-grammar-determiners-1` (8).**
- countability: `much` / `many`, `a lot of`, `plenty of`.
- `few` / `a few` / `little` / `a little` meaning contrast.
- `some` / `any` in statements, questions and negatives.
- `all`, `most`, `both`, `either`, `neither`, `each`, `every`, `no`, `none`.
- demonstratives `this / that / these / those`.
- boundary: no article-choice questions — `a/an/the`/zero belongs to `yds-grammar-articles-*`.

**`yds-grammar-determiners-2` (10).**
- `the number of + plural noun + singular verb` vs `a number of + plural noun + plural verb`.
- `each / every + singular noun + singular verb`; `each of the + plural noun + singular verb`.
- `either / neither of + plural noun + singular verb` (formal).
- `none of` with countable and uncountable nouns.
- `both ... and` (plural), `neither ... nor` / `either ... or` (verb agrees with the nearer subject).
- countability of quantifying phrases: `a great deal of`, `a large amount of`, `a (large) quantity of`, `a considerable number of`.
- `most of the` vs `most`, `all (of) the`.
- `every other`, `each other` vs `one another`.
- `any + singular noun` meaning "whichever" in affirmative sentences.
- boundary: agreement, not article choice.

**`yds-grammar-articles-1` (8).**
- `a` / `an` for first mention, jobs and classification (`a rare condition`, `an engineer`).
- `the` for second mention, unique reference, superlatives, ordinals, and `of`-postmodification (`the development of the region`).
- zero article for generic plurals and uncountables (`Prices fell`, `Research suggests`).
- zero article with proper nouns, meals, languages, academic subjects, `by + transport`.
- `a/an` vs zero with uncountable nouns used countably (`a knowledge of Greek`).
- per quality rule 9, every option carries the whole noun phrase, never a bare dash.

**`yds-grammar-articles-2` (10).**
- institutions: `go to school / to the school`, `in hospital / in the hospital`, `in prison`, `at university`.
- geography: `the Netherlands`, `the Alps`, `the Pacific`, `the Middle East`, `the Nile` vs `Lake Van`, `Mount Ararat`, `Turkey`.
- `the + adjective` for a group (`the unemployed`, `the elderly`).
- `the + comparative` in `the sooner, the better`; `the + superlative + of`.
- fixed phrases: `in the long run`, `on the whole`, `in general`, `at present`, `on average`, `in practice`.
- abstract nouns: generic zero article vs `the` when postmodified (`Education is ...` vs `The education provided by ...`).
- `the fact that`, `play the piano`, `play football`.
- the trap: inserting `the` before a generic plural or an uncountable abstract noun.

### Worked exemplars (ready to ship)

**`yds-grammar-prepositions-2-q01`**

```json
{
  "id": "yds-grammar-prepositions-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The sharp fall in labour productivity is widely attributed ---- two decades of underinvestment in vocational training.",
  "options": [
    "for",
    "to",
    "on",
    "with",
    "from"
  ],
  "correctIndex": 1,
  "explanationTR": "«attribute something TO something» kalıbı sabittir: bir sonucu bir nedene bağlarken to kullanılır. (A) for, blame someone FOR something kalıbına aittir; attribute ile kullanılmaz. (C) on, blame something ON someone kalıbının edatıdır. (D) ve (E) ise bu fiille hiç eşleşmez; «result from» ile karıştırılıyorsa unutma, orada fiil result, burada attribute.",
  "passageID": null
}
```

**`yds-grammar-comparatives-2-q01`**

```json
{
  "id": "yds-grammar-comparatives-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The annual energy consumption of the new data centre is significantly lower than ---- the facility it replaced.",
  "options": [
    "that of",
    "those of",
    "than of",
    "it is",
    "the one"
  ],
  "correctIndex": 0,
  "explanationTR": "Karşılaştırmada aynı türden iki şey karşılaştırılmalıdır: burada karşılaştırılan «energy consumption»dır, «facility» değil. Tekil ve sayılamayan bir ada gönderme yaptığı için that of gerekir. (B) those of çoğul adlar içindir. (C) cümlede zaten bulunan than'i tekrar eder. (D) it is, ardından gelen «the facility» ile birlikte dilbilgisel bir öbek kurmaz; (E) the one ise sayılabilir bir ada gönderir, oysa consumption sayılamaz.",
  "passageID": null
}
```

**`yds-grammar-determiners-2-q01`**

```json
{
  "id": "yds-grammar-determiners-2-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "---- of the two proposals was considered financially viable, so the committee asked for a complete redraft.",
  "options": [
    "None",
    "Neither",
    "Either",
    "Any",
    "Both"
  ],
  "correctIndex": 1,
  "explanationTR": "İKİ şeyin ikisini birden olumsuzlayan belirteç neither'dır ve tekil fiil alır; cümledeki «was» ile de uyuşur. (A) None üç ya da daha fazla öğe için kullanılır, oysa burada «the two proposals» var. (C) Either «ikisinden biri» demektir ve cümleyi «biri uygundu» anlamına çevirir; bu, yeniden yazım istenmesiyle çelişir. (D) Any olumsuz ya da soru cümlesi ister. (E) Both çoğul fiil (were) gerektirir.",
  "passageID": null
}
```

**`yds-grammar-articles-1-q01`**

```json
{
  "id": "yds-grammar-articles-1-q01",
  "kind": "grammar",
  "order": 0,
  "prompt": "The report calls for far greater investment in ----, particularly in rural districts where dropout rates remain high.",
  "options": [
    "the primary education",
    "a primary education",
    "primary education",
    "primary educations",
    "the primary educations"
  ],
  "correctIndex": 2,
  "explanationTR": "«primary education» burada genel olarak bir alanı anlatan sayılamaz bir addır; genel anlamda kullanılan sayılamaz adlar tanımlık almaz. (A) the, ancak ad bir «of» öbeğiyle ya da ilgi cümleciğiyle özelleştirilirse gelir (the primary education provided in these districts). (B) a, sayılamaz adla kullanılmaz. (D) ve (E) ise education'ı çoğullaştırıyor; bu ad bu anlamda çoğul olmaz.",
  "passageID": null
}
```

- [ ] **Step 1: Author the eight lesson files**

Write all eight to the inventory and topic scopes above, applying every quality rule in Global Constraints, with the card style established in Task 2. Plan keys before writing: 8-question files use each key at most three times, 10-question files at most four, never three in a row.

- [ ] **Step 2: Register the unit in `scripts/assemble-content.py`**

Append to `GRAMMAR_UNITS`, after the `yds-grammar-unit-exam-level-structures` entry:

```python
    {
        "id": "yds-grammar-unit-word-level-grammar",
        "theme": "Kelime düzeyinde gramer",
        "order": 8,
        "files": [
            "word-level-grammar/prepositions-1.json",
            "word-level-grammar/prepositions-2.json",
            "word-level-grammar/comparatives-1.json",
            "word-level-grammar/comparatives-2.json",
            "word-level-grammar/determiners-1.json",
            "word-level-grammar/determiners-2.json",
            "word-level-grammar/articles-1.json",
            "word-level-grammar/articles-2.json",
        ],
    },
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: both derived JSON files modified.

- [ ] **Step 4: Update the content-total assertions**

`ContentImporterTests.swift`: `package.units.count` → `9`, `allItems.count` → `157` (count and uniqueness), `grammarPoint` → `32`, `allQuestions.count` → `335` (count and uniqueness). `vocabulary` stays 120, `practiceSet` stays 5, `version` stays 5.

`RealContentSeedingTests.swift`: `package.units.count` → `9`, both `allItems.count` → `157`, questions → `335`, passages stay `3`. In the structure test:

```swift
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.id)),
            [
                "yds-grammar-unit-verbs-and-tenses",
                "yds-grammar-unit-sentence-structures",
                "yds-grammar-unit-verbals-and-linkers",
                "yds-grammar-unit-exam-level-structures",
                "yds-grammar-unit-word-level-grammar",
            ]
        )
        XCTAssertEqual(
            Array(units.dropFirst(4).map(\.theme)),
            [
                "Fiil ve zaman",
                "Cümle yapıları",
                "Fiilimsiler ve bağlantılar",
                "Sınav düzeyi yapılar",
                "Kelime düzeyinde gramer",
            ]
        )
        XCTAssertEqual(units.map(\.order), Array(0..<9), "the package now spans unit orders 0-8")

        let grammarLessons = units.dropFirst(4).flatMap(\.lessons)
        XCTAssertEqual(grammarLessons.count, 30)
        XCTAssertEqual(grammarLessons.flatMap(\.questions).count, 272)
```

and add after the `units[7].lessons` assertion:

```swift
        XCTAssertEqual(
            units[8].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-grammar-prepositions-1",
                "yds-grammar-prepositions-2",
                "yds-grammar-comparatives-1",
                "yds-grammar-comparatives-2",
                "yds-grammar-determiners-1",
                "yds-grammar-determiners-2",
                "yds-grammar-articles-1",
                "yds-grammar-articles-2",
            ]
        )
```

`CoursePathViewModelTests.swift`: `sections.count` → `9`, `sections.last?.unitID` → `"yds-grammar-unit-word-level-grammar"`, `sections.last?.tasks.count` → `8`.

- [ ] **Step 5: Commit**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Kelime düzeyinde gramer grammar unit with 72 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6: Push and confirm both CI workflows green**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 11: Independent review — unit "Kelime düzeyinde gramer"

**Files:**
- Modify (only where defects are found): the eight files under `content/yds-academic-vocab-1/grammar/word-level-grammar/`, then regenerate both derived JSON documents.

**Interfaces:**
- Consumes: Task 10's 72 questions and 8 cards.
- Produces: a corrected question bank plus a written verdict.

**Whoever performs this task must not have authored Task 10** — dispatch a fresh subagent with no Task 10 context.

- [ ] **Step 1: Read the content cold**

Read the eight files under `content/yds-academic-vocab-1/grammar/word-level-grammar/` and the spec's "Content quality rules". Do not read Task 10's exemplars first.

- [ ] **Step 2: Solve every question before looking at any key**

Answer all 72 from stem and options alone, write your answers down, then compare with `correctIndex`.

- [ ] **Step 3: Score every question against the checklist**

Record `ok`, `fix` or `replace` per point, with a one-line reason for anything not `ok`:

1. **Key is correct** (cold answer matches `correctIndex`); disagreement is a `replace`.
2. **Exactly one defensible option** — argue each distractor into correctness; any success is a `fix`.
3. **Distractors are plausible** — nothing obviously wrong at a glance, no length or register cue.
4. **The stem forces the tested point.** Preposition and article items are the most prone to a second acceptable reading: if the sentence works with two prepositions or with and without `the`, it is a `fix`.
5. **`explanationTR` explains why** — rule plus at least two named distractors refuted.
6. **Register and typography** — B2-C1 academic English, exactly one `----`, real Turkish characters, informal "sen".
7. **Key distribution** per file — no key over 40%, no three consecutive identical keys.
8. **Topic independence** — check the plan's "Topic boundaries" table. In this unit specifically: no article-choice items in Determiners, no quantifier-agreement items in Articles, and every article option must carry the whole noun phrase (quality rule 9).

Also review the eight cards: rules correct, English examples grammatical, card covers every rule its own questions test, lesson-2 traps real.

- [ ] **Step 4: Apply fixes at the source, never in the derived JSON**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

- [ ] **Step 5: Stop and escalate if the bank is failing systemically**

More than five `replace` verdicts in this unit means the unit is rewritten, not patched: report and re-open Task 10.

- [ ] **Step 6: Commit (skip if no defects were found)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Kelime düzeyinde gramer grammar unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Push, confirm both CI workflows green, and record the verdict**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Report: 72 questions reviewed, `ok` / `fix` / `replace` counts, every defect with its resolution.

---

## Task 12: Whole-branch review and close

**Files:**
- Modify (only where defects are found): any file under `content/yds-academic-vocab-1/grammar/`, then regenerate both derived JSON documents.
- Read-only: `scripts/assemble-content.py`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`, `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`.

**Interfaces:**
- Consumes: all five reviewed units (30 lessons, 272 questions).
- Produces: the finished slice — a spot-check verdict across units, a final green CI run, and the integration decision.

**This is a cross-unit gate**, so it looks for what a per-unit review cannot see: duplicate stems across units, a rule taught in two cards with different wording, a topic that leaked into another topic's questions.

- [ ] **Step 1: Verify the whole package mechanically**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" - <<'PY'
import importlib.util, os
spec = importlib.util.spec_from_file_location("assemble", os.path.join("scripts", "assemble-content.py"))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
pkg = mod.assemble()
lessons = [l for u in pkg["units"] for l in u["lessons"]]
questions = [q for l in lessons for q in l.get("questions", [])]
grammar = [l for l in lessons if l["id"].startswith("yds-grammar-")]
print("units", len(pkg["units"]))
print("lessons", len(lessons), "grammar lessons", len(grammar))
print("items", sum(len(l["items"]) for l in lessons))
print("questions", len(questions), "grammar questions", sum(len(l["questions"]) for l in grammar))
prompts = {}
for q in questions:
    prompts.setdefault(q["prompt"].strip().lower(), []).append(q["id"])
duplicates = {p: ids for p, ids in prompts.items() if len(ids) > 1}
print("duplicate prompts:", duplicates if duplicates else "none")
PY
```

Expected, exactly: `units 9`, `lessons 49 grammar lessons 30`, `items 157`, `questions 335 grammar questions 272`, `duplicate prompts: none`. Any duplicate prompt is a defect — rewrite one of the two questions.

- [ ] **Step 2: Spot-check answers across all five units**

Pick 30 questions at random across the five units (six per unit, at least two from each unit's lesson-2 files), solve each cold, and compare with `correctIndex`. Also re-read the five lesson-2 "tuzaklar" cards end to end for a rule stated two different ways in two different units.

Any disagreement is a defect: fix at source under `content/yds-academic-vocab-1/grammar/`, regenerate, and note it in the verdict. Two or more disagreements in one unit means that unit's review gate was not applied properly — re-open that unit's review task instead of patching here.

- [ ] **Step 3: Confirm the spec's acceptance criteria one by one**

Check each against the shipped package and record the result:
- 16 topics × 2 lessons, with Tenses and Conditionals contributing lesson 1 from 7a (`yds-practice-lesson-tenses`, `yds-practice-lesson-conditionals`) and lesson 2 from 7b.
- five grammar units at orders 4-8, with the exact themes `Fiil ve zaman`, `Cümle yapıları`, `Fiilimsiler ve bağlantılar`, `Sınav düzeyi yapılar`, `Kelime düzeyinde gramer`.
- lesson 1 = 8 questions, lesson 2 = 10 questions, everywhere.
- package version 5, every pre-existing id unchanged.
- the free preview still shows exactly the first unit's 3 vocabulary + 7 practice lessons and nothing else.
- no new question kind, no importer change, no access-policy change.

- [ ] **Step 4: Commit any fixes (skip if none)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply whole-branch review fixes to the YDS grammar curriculum

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Final CI run**

```bash
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

Both must be green at the branch head.

- [ ] **Step 6: Record the known gap and close the branch**

Record in the report that the new lessons run through the unchanged 7a practice screens, which CI cannot exercise — on-device verification of a grammar lesson (card → 8 or 10 questions → summary → "Tekrar: konu" scheduling) stays on the TestFlight checklist.

Then use the `superpowers:finishing-a-development-branch` skill to decide how the `learning-engine` branch is integrated. Do not merge or push to `master` without that decision.

---

## Self-review

**1. Spec coverage.**

| Spec requirement | Task |
|---|---|
| 16 topics, 2 lessons each, lesson 1 = card + 8 questions, lesson 2 = card + 10 questions | Tasks 2, 4, 6, 8, 10 (inventories) + Task 1 lint (exact counts) |
| The five named units and their topic membership | Unit table; Tasks 2, 4, 6, 8, 10 |
| New units locked for preview users; free unit keeps 3 + 7 lessons | Task 2 preview-access test, updated in Tasks 4, 6, 8, 10 |
| Unit by unit production with an independent review per unit | Tasks 3, 5, 7, 9, 11; >5 `replace` → rewrite (step 5 of each) |
| File layout `grammar/<unit-slug>/<lesson-slug>.json`, one lesson per file | Naming contract + every authoring task's Files block |
| Stable ids `yds-grammar-<topic>-<n>`, card, question ids; 7a ids kept | Naming contract + Task 1 lint (`validate_grammar_lesson`) |
| Unit orders 4-8, lesson order restarts at 0 | Task 1 `load_grammar_units`, unit-order contiguity lint, Task 2 structure test |
| One `grammarPoint` card with `explanationTR`, skill `grammar` | Task 1 lint + Task 2 structure test |
| Durations 8 / 10 minutes | Task 1 lint (`GRAMMAR_LESSON_SHAPE`) |
| Question kind `grammar` for all 7b questions | Task 1 lint + structure test |
| Quality rules 1-7 (plus rulings 8-10) | Global Constraints; enforced by review Tasks 3, 5, 7, 9, 11 |
| `GRAMMAR_UNITS` table; derived JSON byte-stable for existing lessons | Task 1 (empty table, Step 7 diff check) |
| `PACKAGE_VERSION` → 5 in the first content task | Task 2 Step 2 |
| Key-distribution lint, id uniqueness, exact counts, in the CI drift check | Task 1 (the drift-check step already runs the script; no workflow edit needed) |
| No importer change | No task touches `LearningEngine/Sources` |
| Updated `RealContentSeedingTests` / `ContentImporterTests` totals per task | Tasks 2, 4, 6, 8, 10 Step 4/5 |
| New real-content structure test | Task 2 Step 5 |
| New preview-access test | Task 2 Step 6 |
| Final whole-branch review | Task 12 |
| Known gap: screens unverifiable in CI | Task 12 Step 6 |

**2. Placeholder scan.** No "TBD", "TODO" or "handle edge cases" steps. The only deliberately unwritten content is the individual questions, which the spec assigns to the authoring tasks under a binding scope list, worked exemplars, quality rules, a mechanical lint and an independent review gate; every id, count, file path and test value they must hit is fixed in this plan.

**3. Type and name consistency.** `GRAMMAR_UNITS`, `GRAMMAR_DIR`, `GRAMMAR_LESSON_ID_PREFIX`, `GRAMMAR_LESSON_ID_RE`, `GRAMMAR_LESSON_SHAPE`, `MAX_KEY_SHARE`, `load_grammar_units`, `validate_key_distribution`, `validate_grammar_lesson` are defined in Task 1 and used with those exact names in Tasks 2-12. The two Swift tests added in Task 2 (`test_bundledPackage_grammarUnits_areStructurallySound`, `test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked`) are edited, never redeclared, by Tasks 4-10. The two renamed real-content tests (`test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion`, `test_bundledYDSAcademicVocabularyJSON_resolvesFromAppBundle_andImportsEveryItem`) are renamed once, in Task 2, and keep those names afterwards. `units[4]`…`units[8]` index the `sorted` array built at the top of the structure test.

**4. Rulings this plan makes where the spec is silent.**
- The 8/10 count lint keys off the `yds-grammar-` lesson-id prefix, not on `skill == "grammar"`. The two 7a lessons (`yds-practice-lesson-tenses`, `yds-practice-lesson-conditionals`) are therefore exempt — they keep their contractual ids and, as it happens, already have exactly 8 grammar questions each, so they would satisfy the lesson-1 rule anyway. `yds-practice-lesson-sentence-1` also carries skill `grammar` with 15 `sentenceCompletion` questions, which is why a skill-based rule would have been wrong.
- The key-distribution lint applies to **every** lesson with questions. Verified by hand against the shipped files: the worst per-file key share today is 2 of 6 (33%) and no file has three consecutive identical keys, so the rule lands green on existing content.
- The spec's "unit orders 0-8" is asserted as contiguity (`units.map(\.order) == Array(0..<units.count)`) plus an explicit id/theme list per unit task, because only the final unit task actually reaches 9 units; Task 10 adds the literal `Array(0..<9)` assertion.
- Question ids are `-q01`-style zero-padded, matching 7a, and the lint ties `id` to `order`.
- Topic slugs, unit ids, unit-slug directories, titles, headwords, `frequencyRank` (2000-2029) and `baseDifficulty` (0.5 / 0.6) are chosen here; the spec fixed only `yds-grammar-tenses-2` and `yds-grammar-conditionals-2`.
- Quality rulings 8-10 (one blank per stem, no bare-dash options, whole noun phrases in article options) are additions this plan makes so the 7a practice screen renders every new question correctly.
