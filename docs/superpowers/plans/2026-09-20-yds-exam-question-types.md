# YDS Reading and Exam Question Types (Slice 7c) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the YDS exam-type lessons — 33 lessons and 248 questions across four new locked units — as content plus four question-kind labels, the assembly table and the content lint.

**Architecture:** `scripts/assemble-content.py` gains an `EXAM_UNITS` table that loads one lesson document per file from `content/yds-academic-vocab-1/exam/<unit-slug>/` and emits four units at `order` 9-12, after the nine existing units. Every exam lesson is exactly the 7a practice-lesson shape: one `practiceSet` card (no explanation) plus questions of one kind, and a passage for reading and cloze. `QuestionKind` gains four cases; nothing else in the Swift code changes because no screen switches on the kind. Correctness of the questions is enforced by a per-unit independent review gate; the Python lint enforces everything mechanical.

**Tech Stack:** Python 3.12 content assembly, JSON content under `content/yds-academic-vocab-1/`, Swift 5.10 / SwiftUI / SwiftData consumers (`LearningEngine`, `EnglishApp`), GitHub Actions macOS runners (`Swift Tests`, `App Build`) for all verification.

**Spec:** `docs/superpowers/specs/2026-09-20-yds-exam-question-types-design.md`

## Global Constraints

- **No Swift toolchain on this machine.** Never claim a local `swift test` or `xcodebuild` run. Every task's verification is: commit, then **push and confirm both CI workflows green** — `Swift Tests` (`scripts/ci-test.sh`) and `App Build` (`scripts/ci-app-build.sh`). A content-only task still runs both: `Swift Tests` re-runs `assemble-content.py` and diffs the derived files, `App Build` runs the App-target tests that assert the totals.
- **Pushed commits are never amended.** A mistake found after a push is fixed by a new commit.
- **Every git commit message ends with a blank line and then** `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. Use single-quoted heredocs; avoid backticks and `$(...)` inside double-quoted bash strings.
- **Run the assembly script with the real Python interpreter:** `"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py`. Never bare `python`/`python3` (the Microsoft Store alias silently swallows file writes). After every run, confirm with `git status --short` that the two derived JSON files really changed, and delete `scripts/__pycache__/` if it appears.
- **Never hand-edit derived JSON:** `App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json` and `LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json`.
- **Tests assert concrete values** (write the number, never a derived expression).
- **All learner-facing Turkish is real Turkish** (`ı İ ş ğ ü ö ç`, never ASCII substitutes), informal "sen" register, UTF-8, LF, no BOM.
- **Ids are stable and never reused.** No existing id is moved, renamed or re-homed.
- **Original text only.** No ÖSYM or other copyrighted exam material; every passage, dialogue and sentence is written for this app, in domains distinct from the three existing 7a passages (carbon pricing, the digital economy, urbanisation).
- **Content quality rules (binding on every authored question):**
  1. Exactly one defensible correct option; every distractor is refutable in one sentence. "Well, B is arguably fine too" is a defect.
  2. B2-C1 academic register, impersonal prose.
  3. `explanationTR` (2-4 sentences) states the reasoning that makes the key correct **and** names and refutes at least two specific distractors. The `(A)`-`(E)` letters in it must match the real option positions.
  4. Key distribution per lesson: no key over 40 % of that lesson's questions and never three consecutive identical keys (the lint enforces both).
  5. Options are similar in length and register; no length cue, no joke or obviously-wrong filler, no ungrammatical junk distractor.
  6. Later lessons of a type are harder and exercise real YDS traps: over-reading the passage, absolute words (`always`, `never`, `only`), near-synonym distractors, connector/tense mismatch, true-but-not-stated options.
  7. No question is answerable without the passage or stem it belongs to; no question is answerable from another question's stem.
  8. Stem + KEY must read as a fully grammatical, natural sentence; no word duplicated next to the blank.
  9. One blank per stem for sentence, paragraph and dialogue lessons (exactly one `----`).
  10. Passages: 170-280 words (target 180-260), original, one topic each, every passage in a different domain.

---

## Naming and id contract (binding — the lint enforces it)

- Lesson file: `content/yds-academic-vocab-1/exam/<unit-slug>/<type>-<n>.json`, one lesson document per file, **without** an `order` key.
- Lesson id `yds-exam-<type>-<n>`; card id `yds-exam-card-<type>-<n>`; question id `<lesson id>-q<NN>` (`NN` zero-padded from `01`, `order = NN - 1`); passage id `yds-exam-passage-<type>-<n>` (reading and cloze only).
- Every exam lesson: exactly one item, `"type": "practiceSet"`, **no `explanationTR` key on it**, `exampleSentences: []`, `collocations: []`, `frequencyRank` as in the inventories (unique, 3000 and up), `baseDifficulty` 0.5 for `n=1`, 0.55 for `n=2`, 0.6 for `n=3`, 0.65 for `n>=4`, `definition` one Turkish line, `translationTR` the Turkish lesson title, `headword` an English label.
- Lesson JSON shape: `id`, `estimatedDurationMinutes`, `title` (Turkish), `skill`, optional `passage` (`id`, `title`, `body`), `items` (the one card), `questions`.
- Question JSON shape: `id`, `kind`, `order`, `prompt`, `options` (exactly five, all distinct), `correctIndex`, `explanationTR`, `passageID` (the lesson's passage id for reading/cloze, `null` otherwise).

### Lesson shapes (exact — the lint enforces them)

| type | kind | skill | passage | questions | minutes |
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

### Unit table (ids, orders and themes are contractual)

| order | unit id | theme | directory | lessons | questions |
|---|---|---|---|---|---|
| 9 | `yds-exam-unit-reading` | `Okuma anlama` | `exam/reading/` | 8 | 40 |
| 10 | `yds-exam-unit-cloze-sentence` | `Cloze ve cümle tamamlama` | `exam/cloze-sentence/` | 8 | 72 |
| 11 | `yds-exam-unit-paragraph` | `Paragraf soruları` | `exam/paragraph/` | 8 | 64 |
| 12 | `yds-exam-unit-translation-restatement` | `Çeviri ve yeniden ifade` | `exam/translation-restatement/` | 9 | 72 |

33 new lessons, 33 new `practiceSet` cards, **248** new questions, 12 passages.

### Running totals to assert after each task

Baseline on the branch today: 9 units, 49 lessons, 157 items (120 `vocabulary` + 32 `grammarPoint` + 5 `practiceSet`), 335 questions, 3 passages, package version 6.

| After task | units | lessons | items | `practiceSet` items | questions | passages | version |
|---|---|---|---|---|---|---|---|
| 2 (Okuma anlama) | 10 | 57 | 165 | 13 | 375 | 11 | 7 |
| 4 (Cloze ve cümle tamamlama) | 11 | 65 | 173 | 21 | 447 | 15 | 7 |
| 6 (Paragraf soruları) | 12 | 73 | 181 | 29 | 511 | 15 | 7 |
| 8 (Çeviri ve yeniden ifade) | 13 | 82 | 190 | 38 | 583 | 15 | 7 |

`vocabulary` stays 120 and `grammarPoint` stays 32 throughout.

## Review procedure (shared by Tasks 3, 5, 7 and 9)

**Whoever performs a review must not have authored the unit.** Under subagent-driven execution dispatch a fresh subagent with no authoring context; give it this section, the unit's file list and the global quality rules.

1. **Read cold.** Read the unit's lesson files. Do not read the exemplars or topic scopes first.
2. **Solve every question before looking at any key.** Decide the answer from the stem and options, write it down, then compare with `correctIndex`. A disagreement still held after re-reading is a `replace`. For reading and cloze, read the passage first, then solve.
3. **Score every question** `ok` / `fix` / `replace` on: (1) key correct; (2) exactly one defensible option — try to argue every distractor into correctness; (3) distractors plausible, not junk, similar length; (4) the stem forces the tested point; (5) `explanationTR` gives the reasoning and refutes at least two named distractors, with correct `(A)`-`(E)` letters; (6) register, exactly one `----` where required, real Turkish characters; (7) key distribution; (8) topic and type independence; (9) stem + key reads as a natural sentence.
4. **Passages and cards:** original, single-topic, 170-280 words, a domain different from every other passage, no factual error a candidate could learn wrongly, and every reading/cloze question answerable from the passage alone.
5. **Fix at the source** under `content/yds-academic-vocab-1/exam/`, never in the derived JSON. Keep ids, orders, counts, minutes, five options and exactly-one-`----` rules; regenerate with the real Python and confirm both derived files changed.
6. **More than five `replace` in one unit:** stop, do not patch, report the verdict and re-open the authoring task for a rewrite of the unit.
7. **Commit** any fixes with the message shown in the task, push, confirm both CI workflows green, and report: questions reviewed, counts of `ok` / `fix` / `replace`, every defect with its resolution.

## Authoring helper (used by Tasks 2, 4, 6 and 8)

Author every lesson with one generator script kept in the scratchpad directory (never committed), so JSON validity is guaranteed and explanation letters are computed instead of typed. Create `<scratchpad>/exam_common.py` once:

```python
import json, os, re

ROOT = "C:/Users/niino/Desktop/ENGLISH/.worktrees/learning-engine/content/yds-academic-vocab-1/exam"
LETTERS = "ABCDE"


def Q(prompt, correct, distractors, key, expl, passage_id=None):
    """Place `correct` at index `key` among the four distractors.
    In `expl`, <K> becomes the letter of the correct option and <1>..<4> the
    letters of the distractors in the order given."""
    assert len(distractors) == 4, prompt
    options = list(distractors)
    options.insert(key, correct)
    assert len(set(options)) == 5, ("duplicate options", prompt)
    letter = {"K": LETTERS[key]}
    pos = 0
    for i in range(1, 5):
        if pos == key:
            pos += 1
        letter[str(i)] = LETTERS[pos]
        pos += 1
    text = re.sub(r"<([K1-4])>", lambda m: "(" + letter[m.group(1)] + ")", expl)
    return {"prompt": prompt, "options": options, "correctIndex": key, "explanationTR": text, "passageID": passage_id}


def lesson(unit_dir, type_, n, title, headword, rank, definition, minutes, skill, kind, questions, passage=None):
    lid = f"yds-exam-{type_}-{n}"
    diff = {1: 0.5, 2: 0.55, 3: 0.6}.get(n, 0.65)
    doc = {"id": lid, "estimatedDurationMinutes": minutes, "title": title, "skill": skill}
    if passage:
        doc["passage"] = {"id": f"yds-exam-passage-{type_}-{n}", "title": passage[0], "body": passage[1]}
    doc["items"] = [{
        "id": f"yds-exam-card-{type_}-{n}", "type": "practiceSet", "headword": headword,
        "frequencyRank": rank, "baseDifficulty": diff, "definition": definition,
        "exampleSentences": [], "translationTR": title, "collocations": [],
    }]
    doc["questions"] = []
    for i, q in enumerate(questions):
        q = dict(q)
        q["id"] = f"{lid}-q{i + 1:02d}"
        q["kind"] = kind
        q["order"] = i
        if passage:
            q["passageID"] = doc["passage"]["id"]
        doc["questions"].append({k: q[k] for k in ("id", "kind", "order", "prompt", "options", "correctIndex", "explanationTR", "passageID")})
    out = os.path.join(ROOT, unit_dir)
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, f"{type_}-{n}.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
```

Each authoring task writes `<scratchpad>/gen_<unit>.py` that does `from exam_common import Q, lesson` (add the scratchpad to `sys.path`) and calls `lesson(...)` once per lesson. Long Python files that contain Turkish and quotes must be written with the Write tool, not a Bash heredoc.

---

## Task 1: Question kinds, assembly table and exam lint (no content yet)

**Files:**
- Modify: `LearningEngine/Sources/LearningEngine/Models/Question.swift`
- Modify: `scripts/assemble-content.py`
- Test: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`
- Verify unchanged: both derived JSON files

**Interfaces:**
- Produces: `QuestionKind.paragraphCompletion`, `.irrelevantSentence`, `.dialogueCompletion`, `.restatement`; in the script `EXAM_DIR`, `EXAM_UNITS` (empty), `EXAM_LESSON_SHAPE`, `load_exam_units()`, `validate_exam_lesson()`. With `EXAM_UNITS` empty the derived JSON stays **byte-identical**.

- [ ] **Step 1: Add the four kinds**

In `Question.swift` replace the enum with:

```swift
public enum QuestionKind: String, Codable, CaseIterable, Sendable {
    case grammar, reading, cloze, sentenceCompletion, translation
    case paragraphCompletion, irrelevantSentence, dialogueCompletion, restatement
}
```

- [ ] **Step 2: Importer test for the new kinds**

Add to `ContentImporterTests.swift`, next to `test_importPackage_unknownQuestionKind_throws`'s neighbours (search for `.invalidQuestionKind("essay")`):

```swift
    func test_importPackage_acceptsEveryExamQuestionKind() throws {
        for kind in ["paragraphCompletion", "irrelevantSentence", "dialogueCompletion", "restatement"] {
            let context = try makeInMemoryContext()
            let package = try ContentImporter.importPackage(from: practiceJSON(questionKind: kind), into: context)
            let questions = package.units.flatMap(\.lessons).flatMap(\.questions)
            XCTAssertEqual(questions.map { $0.kind.rawValue }, [kind, kind], kind)
        }
    }
```

- [ ] **Step 3: Script — constants, kinds, table**

In `scripts/assemble-content.py` replace the `QUESTION_KINDS` line with:

```python
QUESTION_KINDS = {
    "grammar", "reading", "cloze", "sentenceCompletion", "translation",
    "paragraphCompletion", "irrelevantSentence", "dialogueCompletion", "restatement",
}
```

and add, directly after the `GRAMMAR_LESSON_SHAPE = ...` / `MAX_KEY_SHARE` block:

```python
EXAM_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "exam")

# Slice 7c exam-type units, emitted after the grammar units (orders 9-12).
# Same contract as GRAMMAR_UNITS: `files` are relative to EXAM_DIR, one lesson
# document per file without an `order` key; list position is the lesson order.
# An empty table leaves the derived JSON byte-identical.
EXAM_UNITS = []

EXAM_LESSON_ID_PREFIX = "yds-exam-"
# type -> (question kind, lesson skill, has passage, exact question count, exact minutes)
EXAM_LESSON_SHAPE = {
    "reading": ("reading", "reading", True, 5, 10),
    "cloze": ("cloze", "reading", True, 8, 10),
    "sentence": ("sentenceCompletion", "grammar", False, 10, 9),
    "paragraph": ("paragraphCompletion", "reading", False, 8, 10),
    "irrelevant": ("irrelevantSentence", "reading", False, 8, 9),
    "dialogue": ("dialogueCompletion", "grammar", False, 8, 8),
    "translation-en-tr": ("translation", "reading", False, 8, 9),
    "translation-tr-en": ("translation", "reading", False, 8, 9),
    "restatement": ("restatement", "reading", False, 8, 9),
}
EXAM_LESSON_ID_RE = re.compile(
    r"^yds-exam-(" + "|".join(sorted(EXAM_LESSON_SHAPE, key=len, reverse=True)) + r")-([1-9][0-9]*)$"
)
EXAM_PASSAGE_MIN_WORDS = 170
EXAM_PASSAGE_MAX_WORDS = 280
ROMAN = ["I", "II", "III", "IV", "V"]
```

- [ ] **Step 4: Script — loader and lint**

Add after `load_grammar_units()`:

```python
def load_exam_units():
    """Builds the Slice 7c exam units from EXAM_UNITS; lesson `order` comes
    from list position, exactly like load_grammar_units."""
    units = []
    for unit_spec in EXAM_UNITS:
        lessons = []
        for order, filename in enumerate(unit_spec["files"]):
            path = os.path.join(EXAM_DIR, filename)
            with open(path, "r", encoding="utf-8") as f:
                lesson = json.load(f)
            if not lesson["id"].startswith(EXAM_LESSON_ID_PREFIX):
                raise ValueError(
                    f"exam lesson {lesson['id']} (from {filename}) must start with "
                    f"{EXAM_LESSON_ID_PREFIX!r}, otherwise the exam lint skips it"
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

and add after `validate_grammar_lesson()`:

```python
def validate_exam_lesson(lesson):
    """Shape rules for Slice 7c exam lessons, keyed off the lesson id prefix."""
    lesson_id = lesson["id"]
    match = EXAM_LESSON_ID_RE.match(lesson_id)
    if match is None:
        raise ValueError(f"exam lesson id {lesson_id!r} does not match yds-exam-<type>-<n>")
    type_, n = match.group(1), match.group(2)
    kind, skill, has_passage, expected_questions, expected_minutes = EXAM_LESSON_SHAPE[type_]

    if lesson["skill"] != skill:
        raise ValueError(f"exam lesson {lesson_id} must have skill {skill!r}, found {lesson['skill']!r}")
    if lesson["estimatedDurationMinutes"] != expected_minutes:
        raise ValueError(
            f"exam lesson {lesson_id} must have estimatedDurationMinutes {expected_minutes}, "
            f"found {lesson['estimatedDurationMinutes']}"
        )

    passage = lesson.get("passage")
    passage_id = f"yds-exam-passage-{type_}-{n}"
    if has_passage:
        if passage is None:
            raise ValueError(f"exam lesson {lesson_id} must carry a passage")
        if passage["id"] != passage_id:
            raise ValueError(f"exam lesson {lesson_id}: passage id {passage['id']!r} must be {passage_id!r}")
        if not passage["title"].strip():
            raise ValueError(f"exam lesson {lesson_id}: empty passage title")
        words = len(passage["body"].split())
        if not EXAM_PASSAGE_MIN_WORDS <= words <= EXAM_PASSAGE_MAX_WORDS:
            raise ValueError(
                f"exam lesson {lesson_id}: passage has {words} words, expected "
                f"{EXAM_PASSAGE_MIN_WORDS}-{EXAM_PASSAGE_MAX_WORDS}"
            )
    elif passage is not None:
        raise ValueError(f"exam lesson {lesson_id} must not carry a passage")

    if len(lesson["items"]) != 1 or lesson["items"][0]["type"] != "practiceSet":
        raise ValueError(f"exam lesson {lesson_id} must own exactly one practiceSet item")
    card = lesson["items"][0]
    expected_card_id = f"yds-exam-card-{type_}-{n}"
    if card["id"] != expected_card_id:
        raise ValueError(f"exam lesson {lesson_id}: card id {card['id']!r} must be {expected_card_id!r}")

    questions = lesson.get("questions", [])
    if len(questions) != expected_questions:
        raise ValueError(
            f"exam lesson {lesson_id} must have exactly {expected_questions} questions, found {len(questions)}"
        )
    for index, question in enumerate(sorted(questions, key=lambda q: q["order"])):
        qid = question["id"]
        if question["kind"] != kind:
            raise ValueError(f"question {qid} in {lesson_id} must have kind {kind!r}, found {question['kind']!r}")
        if question["order"] != index:
            raise ValueError(f"lesson {lesson_id} question orders must be 0..{expected_questions - 1} with no gaps")
        if qid != f"{lesson_id}-q{index + 1:02d}":
            raise ValueError(f"question at order {index} in {lesson_id} must be named {lesson_id}-q{index + 1:02d}")
        if len(set(question["options"])) != 5:
            raise ValueError(f"question {qid} has duplicate options")
        expected_passage = passage_id if has_passage else None
        if question.get("passageID") != expected_passage:
            raise ValueError(f"question {qid} must have passageID {expected_passage!r}")

        prompt = question["prompt"]
        if type_ in ("sentence", "paragraph", "dialogue") and prompt.count("----") != 1:
            raise ValueError(f"question {qid} must contain exactly one '----'")
        if type_ == "cloze":
            k = index + 1
            if prompt.count("----") != 1 or f"({k}) ----" not in prompt:
                raise ValueError(f"question {qid} must contain exactly one '({k}) ----'")
            if f"({k})----" not in passage["body"]:
                raise ValueError(f"lesson {lesson_id}: passage is missing the blank '({k})----'")
        if type_ == "irrelevant":
            if question["options"] != ROMAN:
                raise ValueError(f"question {qid} options must be exactly {ROMAN}")
            for numeral in ROMAN:
                if f"({numeral})" not in prompt:
                    raise ValueError(f"question {qid} stem is missing the numbered sentence ({numeral})")
```

- [ ] **Step 5: Script — hook the lint and the loader**

In `validate_content`, directly below the existing

```python
            if lesson_id.startswith(GRAMMAR_LESSON_ID_PREFIX):
                validate_grammar_lesson(lesson)
```

add

```python
            if lesson_id.startswith(EXAM_LESSON_ID_PREFIX):
                validate_exam_lesson(lesson)
```

and change the units line in `assemble()` to

```python
    units = attach_practice_lessons(load_units()) + load_grammar_units() + load_exam_units()
```

- [ ] **Step 6: Lint self-check (scratchpad script, never committed)**

Create `<scratchpad>/lint_check_exam.py`:

```python
import importlib.util, os, sys
os.chdir("C:/Users/niino/Desktop/ENGLISH/.worktrees/learning-engine")
spec = importlib.util.spec_from_file_location("assemble", "scripts/assemble-content.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

def make(type_="sentence", n=1, **over):
    kind, skill, has_passage, count, minutes = mod.EXAM_LESSON_SHAPE[type_]
    lid = f"yds-exam-{type_}-{n}"
    passage_id = f"yds-exam-passage-{type_}-{n}"
    body = " ".join(["word"] * 200)
    if type_ == "cloze":
        body = " ".join(f"({k})----" for k in range(1, count + 1)) + " " + body
    lesson = {
        "id": lid, "order": 0, "estimatedDurationMinutes": minutes, "title": "t", "skill": skill,
        "items": [{"id": f"yds-exam-card-{type_}-{n}", "type": "practiceSet"}],
        "questions": [],
    }
    if has_passage:
        lesson["passage"] = {"id": passage_id, "title": "T", "body": body}
    keys = [1, 3, 0, 2, 4, 1, 3, 0, 2, 4]
    for i in range(count):
        prompt = "Some stem ----."
        options = ["a", "b", "c", "d", "e"]
        if type_ == "cloze":
            prompt = f"({i + 1}) ---- text"
        if type_ == "irrelevant":
            prompt = " ".join(f"({r}) s." for r in mod.ROMAN)
            options = list(mod.ROMAN)
        lesson["questions"].append({
            "id": f"{lid}-q{i + 1:02d}", "kind": kind, "order": i, "prompt": prompt, "options": options,
            "correctIndex": keys[i], "explanationTR": "x", "passageID": passage_id if has_passage else None,
        })
    lesson.update(over)
    return lesson

def expect_ok(name, lesson):
    mod.validate_exam_lesson(lesson); print("PASS", name)

def expect_fail(name, lesson, fragment):
    try:
        mod.validate_exam_lesson(lesson)
    except ValueError as e:
        assert fragment in str(e), (name, str(e)); print("PASS", name)
    else:
        raise SystemExit(f"FAIL {name}: no error")

for t in mod.EXAM_LESSON_SHAPE:
    expect_ok(f"valid {t}", make(t))
expect_fail("bad id", make(id="yds-exam-bogus-1"), "does not match")
expect_fail("wrong skill", make("sentence", skill="reading"), "skill")
expect_fail("wrong minutes", make("reading", estimatedDurationMinutes=9), "estimatedDurationMinutes")
l = make("sentence"); l["questions"].pop(); expect_fail("too few questions", l, "exactly 10")
l = make("sentence"); l["questions"][0]["kind"] = "reading"; expect_fail("wrong kind", l, "kind")
l = make("sentence"); l["questions"][0]["prompt"] = "no blank"; expect_fail("no blank", l, "exactly one '----'")
l = make("sentence"); l["questions"][0]["options"] = ["a", "a", "c", "d", "e"]; expect_fail("duplicate options", l, "duplicate")
l = make("reading"); l["passage"]["body"] = "too short"; expect_fail("short passage", l, "words")
l = make("reading"); del l["passage"]; expect_fail("missing passage", l, "must carry a passage")
l = make("sentence"); l["passage"] = {"id": "x", "title": "t", "body": "b"}; expect_fail("unexpected passage", l, "must not carry")
l = make("cloze"); l["passage"]["body"] = l["passage"]["body"].replace("(3)----", "(3)"); expect_fail("cloze blank missing", l, "(3)----")
l = make("cloze"); l["questions"][0]["prompt"] = "no marker ----"; expect_fail("cloze marker", l, "(1) ----")
l = make("irrelevant"); l["questions"][0]["options"] = ["I", "II", "III", "IV", "VI"]; expect_fail("roman options", l, "options must be exactly")
l = make("irrelevant"); l["questions"][0]["prompt"] = "(I) only"; expect_fail("numbered sentences", l, "numbered sentence")
l = make("sentence"); l["items"][0]["type"] = "grammarPoint"; expect_fail("card type", l, "practiceSet")
print("ALL CHECKS PASSED")
```

Run it with the real interpreter. Expected: every line `PASS`, then `ALL CHECKS PASSED`.

- [ ] **Step 7: Confirm the derived JSON is unchanged**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
```

Expected: only `Question.swift`, the script and `ContentImporterTests.swift` are modified; the two derived JSON files must **not** appear (an empty `EXAM_UNITS` adds nothing).

- [ ] **Step 8: Commit, push, confirm both CI workflows green**

```bash
git add LearningEngine scripts/assemble-content.py
git commit -m "$(cat <<'EOF'
Add exam question kinds, the exam unit table and the exam lesson lint for Slice 7c

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 2: Unit "Okuma anlama" — 8 reading lessons, 40 questions, package version 7

**Files:**
- Create: `content/yds-academic-vocab-1/exam/reading/reading-1.json` … `reading-8.json`
- Modify: `scripts/assemble-content.py` (`EXAM_UNITS` first entry, `PACKAGE_VERSION` 6 → 7)
- Regenerate: both derived JSON files
- Modify: `LearningEngine/Tests/LearningEngineTests/ContentImporterTests.swift`, `App/Tests/EnglishAppTests/RealContentSeedingTests.swift`, `App/Tests/EnglishAppTests/CoursePathViewModelTests.swift`

**Interfaces:**
- Consumes: Task 1's table, loader and lint.
- Produces: version **7**; unit `yds-exam-unit-reading` at order 9 with lessons `yds-exam-reading-1` … `-8`; the test `test_bundledPackage_examUnits_areStructurallySound()` that every later unit task extends rather than duplicates.

### Lesson inventory (contractual)

| order | file | lesson id | title | headword | freqRank | passage title | domain |
|---|---|---|---|---|---|---|---|
| 0 | `reading-1.json` | `yds-exam-reading-1` | `Okuma: Uyku ve Bellek` | `Reading: Sleep and Memory` | 3000 | Sleep and Memory | health / psychology |
| 1 | `reading-2.json` | `yds-exam-reading-2` | `Okuma: Uzaktan Çalışmanın Ekonomisi` | `Reading: The Economics of Remote Work` | 3001 | The Economics of Remote Work | labour economics |
| 2 | `reading-3.json` | `yds-exam-reading-3` | `Okuma: Antibiyotik Direnci` | `Reading: Antibiotic Resistance` | 3002 | Antibiotic Resistance | medicine |
| 3 | `reading-4.json` | `yds-exam-reading-4` | `Okuma: Kentsel Isı Adaları` | `Reading: Urban Heat Islands` | 3003 | Urban Heat Islands | environment / urbanism |
| 4 | `reading-5.json` | `yds-exam-reading-5` | `Okuma: Matbaa ve Okuryazarlık` | `Reading: The Printing Press and Literacy` | 3004 | The Printing Press and Literacy | history |
| 5 | `reading-6.json` | `yds-exam-reading-6` | `Okuma: Algoritmik İşe Alım` | `Reading: Algorithmic Hiring` | 3005 | Algorithmic Hiring | technology / ethics |
| 6 | `reading-7.json` | `yds-exam-reading-7` | `Okuma: Enerji Depolama` | `Reading: Energy Storage` | 3006 | Energy Storage | energy / engineering |
| 7 | `reading-8.json` | `yds-exam-reading-8` | `Okuma: Yetişkinlerde Dil Öğrenimi` | `Reading: Adult Language Learning` | 3007 | Adult Language Learning | education / linguistics |

`definition` for each: `"<konu> üzerine akademik bir metin ve beş okuduğunu anlama sorusu."` (Turkish topic phrase). Question ids `yds-exam-reading-<n>-q01` … `-q05`. 40 questions total. Minutes 10, skill `reading`, kind `reading`.

### Per-lesson question scope (5 questions each; every lesson draws its five from this list)

Question sub-skills: **main idea / best title**, **stated detail**, **inference** (implied, not stated), **vocabulary in context** ("the word 'X' as used in the passage is closest in meaning to ----"), **reference** (what does "this"/"they" refer to), **purpose or attitude**, **negative** ("all of the following EXCEPT" is rendered as a stem ending `----` where four options are stated and one is not).

- Lessons 1-2: two detail, one main idea, one vocabulary-in-context, one inference (gentle).
- Lessons 3-5: one main idea, one detail, one negative/not-stated, one inference, one reference or purpose.
- Lessons 6-8: two inferences, one attitude/purpose, one vocabulary-in-context with a near-synonym trap, one true-but-not-stated distractor trap. At least one distractor per lesson is an absolute (`always`, `never`, `only`) that the passage does not license.

Reading stems are English questions or sentences ending in `----`; every stem's `passageID` is the lesson's passage id; every option is a complete phrase of similar length.

### Worked exemplars (the style bar)

**Passage `yds-exam-passage-reading-1`, "Sleep and Memory" (excerpt of the shape — write each real passage 180-260 words):**

```json
{
  "id": "yds-exam-passage-reading-1",
  "title": "Sleep and Memory",
  "body": "For decades, sleep was treated as a passive state in which the brain simply switched off. Research over the past thirty years has overturned that view. During deep sleep, the hippocampus replays the day's experiences, and the brain gradually transfers them to the cortex, where they are stored as long-term memories. Volunteers who slept after learning a list of word pairs recalled roughly twenty per cent more of them the next morning than those who stayed awake for the same period, even though both groups had studied for equal lengths of time. Crucially, the benefit was largest for material that participants had found difficult, which suggests that sleep does not strengthen all memories equally but favours those the brain judges worth keeping. This finding has practical consequences. Students who sacrifice sleep to revise late into the night may feel that they are gaining study time, yet they risk losing the very consolidation that would make the extra hours worthwhile. Sleep researchers are careful, however, not to overstate the case: napping cannot substitute for a full night's rest, and no amount of sleep will make up for material that was never properly understood in the first place."
}
```

**A reading question:**

```json
{
  "id": "yds-exam-reading-1-q02",
  "kind": "reading",
  "order": 1,
  "prompt": "According to the passage, the memory advantage of sleeping after learning was greatest for ----.",
  "options": [
    "word pairs that had been studied for the longest time",
    "information that learners had found hard to master",
    "material that had already been understood thoroughly",
    "facts learned shortly before a brief afternoon nap",
    "lists that were shorter than those given to the awake group"
  ],
  "correctIndex": 1,
  "explanationTR": "Metin, faydanın «katılımcıların zor bulduğu malzemede» en büyük olduğunu söylüyor; bu, (B) seçeneğidir. (A) çalışma süresi iki grupta eşitti, bu yüzden fark yaratmaz. (C) metin zaten iyi anlaşılmış malzemeden değil, zor bulunandan söz eder. (D) kısa şekerleme metinde tam gece uykusunun yerini tutmadığı biçiminde geçer, en büyük fayda olarak değil.",
  "passageID": "yds-exam-passage-reading-1"
}
```

(The exemplar's letters are illustrative; in generated files they are computed by `Q`, and `correctIndex` above is the position of the key in that option list.)

### Steps

- [ ] **Step 1: Author the eight lesson files** with the authoring helper, to the inventory and scope above. Write the eight passages first (one domain each, none about carbon pricing, the digital economy or urbanisation), then five questions per passage. Plan each lesson's keys before writing so the lint passes: five questions, each key at most twice, never three in a row (for example `[2, 0, 3, 1, 4]` and rotations). Set `unit_dir="reading"`.

- [ ] **Step 2: Register the unit and bump the version**

In `scripts/assemble-content.py` replace `EXAM_UNITS = []` with:

```python
EXAM_UNITS = [
    {
        "id": "yds-exam-unit-reading",
        "theme": "Okuma anlama",
        "order": 9,
        "files": [
            "reading/reading-1.json",
            "reading/reading-2.json",
            "reading/reading-3.json",
            "reading/reading-4.json",
            "reading/reading-5.json",
            "reading/reading-6.json",
            "reading/reading-7.json",
            "reading/reading-8.json",
        ],
    },
]
```

and replace the version block's value and add its comment line, so it ends:

```python
# 7: Slice 7c adds the exam-type units (orders 9-12). Bumping this makes
# installed apps re-import the package; every existing id is unchanged, so
# FSRS history survives the reseed.
PACKAGE_VERSION = 7
```

(keep the earlier `# 4`, `# 5`, `# 6` comment lines above it).

- [ ] **Step 3: Regenerate with the real Python and check the diff**

```bash
"C:/Users/niino/AppData/Local/Programs/Python/Python312/python.exe" scripts/assemble-content.py
git status --short
git diff --stat
```

Expected: both derived JSON files modified. If the script raises, fix the content: the message names the lesson, the question and the broken rule.

- [ ] **Step 4: Update the LearningEngine totals test**

In `ContentImporterTests.swift`, in `test_importPackage_realYDSPackage_importsEveryUnitItemAndQuestion` change: `package.version` `6` → `7`; `package.units.count` `9` → `10`; both `157` → `165`; the `.practiceSet` count `5` → `13`; both `335` → `375`. Leave `.vocabulary` 120 and `.grammarPoint` 32.

- [ ] **Step 5: Update `RealContentSeedingTests` and add the exam structure test**

In `RealContentSeedingTests.swift`: `package.units.count` `9` → `10`; both `allItems.count` `157` → `165`; `package.version` `6` → `7`; the questions count `335` → `375`; the passages count `3` → `11`.

Narrow the 7b grammar structure test to the grammar units. In `test_bundledPackage_grammarUnits_areStructurallySound` replace `units.dropFirst(4).map(\.id)` with `units[4..<9].map(\.id)`, `units.dropFirst(4).map(\.theme)` with `units[4..<9].map(\.theme)` and `let grammarLessons = units.dropFirst(4).flatMap(\.lessons)` with `let grammarLessons = units[4..<9].flatMap(\.lessons)`.

Add this test to the same file — every later unit task edits only its three lists and counts:

```swift
    private struct ExamShape {
        let kind: QuestionKind
        let skill: Skill
        let hasPassage: Bool
        let questions: Int
        let minutes: Int
    }

    private static let examShapes: [String: ExamShape] = [
        "reading": ExamShape(kind: .reading, skill: .reading, hasPassage: true, questions: 5, minutes: 10),
        "cloze": ExamShape(kind: .cloze, skill: .reading, hasPassage: true, questions: 8, minutes: 10),
        "sentence": ExamShape(kind: .sentenceCompletion, skill: .grammar, hasPassage: false, questions: 10, minutes: 9),
        "paragraph": ExamShape(kind: .paragraphCompletion, skill: .reading, hasPassage: false, questions: 8, minutes: 10),
        "irrelevant": ExamShape(kind: .irrelevantSentence, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "dialogue": ExamShape(kind: .dialogueCompletion, skill: .grammar, hasPassage: false, questions: 8, minutes: 8),
        "translation-en-tr": ExamShape(kind: .translation, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "translation-tr-en": ExamShape(kind: .translation, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
        "restatement": ExamShape(kind: .restatement, skill: .reading, hasPassage: false, questions: 8, minutes: 9),
    ]

    /// Structure gate for the Slice 7c exam units, read from the shipped app
    /// resource. Content correctness is the per-unit review gate's job.
    func test_bundledPackage_examUnits_areStructurallySound() throws {
        guard let url = Bundle.main.url(forResource: "YDSAcademicVocabulary1", withExtension: "json") else {
            XCTFail("YDSAcademicVocabulary1.json not found in the app bundle")
            return
        }
        let context = try makeInMemoryContext()
        let package = try ContentImporter.importPackage(from: try Data(contentsOf: url), into: context)
        try context.save()

        let units = package.units.sorted { $0.order < $1.order }
        XCTAssertEqual(units.map(\.order), Array(0..<units.count), "unit orders must be contiguous from 0")
        let examUnits = Array(units.dropFirst(9))
        XCTAssertEqual(examUnits.map(\.id), ["yds-exam-unit-reading"])
        XCTAssertEqual(examUnits.map(\.theme), ["Okuma anlama"])
        XCTAssertEqual(examUnits.map(\.order), [9])
        XCTAssertEqual(
            units[9].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-reading-1", "yds-exam-reading-2", "yds-exam-reading-3", "yds-exam-reading-4",
                "yds-exam-reading-5", "yds-exam-reading-6", "yds-exam-reading-7", "yds-exam-reading-8",
            ]
        )

        for lesson in examUnits.flatMap(\.lessons) {
            let rest = String(lesson.id.dropFirst("yds-exam-".count))
            let type = String(rest[..<rest.lastIndex(of: "-")!])
            let shape = try XCTUnwrap(Self.examShapes[type], lesson.id)
            XCTAssertEqual(lesson.skill, shape.skill, lesson.id)
            XCTAssertEqual(lesson.estimatedDurationMinutes, shape.minutes, lesson.id)
            XCTAssertEqual(lesson.items.count, 1, "\(lesson.id) must own exactly one card")
            let card = try XCTUnwrap(lesson.items.first)
            XCTAssertEqual(card.type, .practiceSet, lesson.id)
            XCTAssertEqual(card.id, "yds-exam-card-" + rest, lesson.id)
            XCTAssertTrue((card.content?.explanationTR ?? "").isEmpty, "\(lesson.id) practiceSet card must not carry an explanation")
            XCTAssertEqual(lesson.questions.count, shape.questions, lesson.id)
            XCTAssertEqual(lesson.passage != nil, shape.hasPassage, lesson.id)
            for question in lesson.questions {
                XCTAssertEqual(question.kind, shape.kind, question.id)
                XCTAssertEqual(question.options.count, 5, question.id)
                XCTAssertTrue((0...4).contains(question.correctIndex), question.id)
                XCTAssertFalse(question.explanationTR.isEmpty, question.id)
                XCTAssertEqual(question.passage?.id, lesson.passage?.id, question.id)
            }
            if type == "cloze", let body = lesson.passage?.body {
                for k in 1...shape.questions {
                    XCTAssertTrue(body.contains("(\(k))----"), "\(lesson.id) passage is missing blank (\(k))")
                }
            }
        }
    }
```

- [ ] **Step 6: Update the preview-access test**

In `CoursePathViewModelTests.swift`, in `test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked`: `sections.count` `9` → `10`; `sections.last?.unitID` → `"yds-exam-unit-reading"`; `sections.last?.tasks.count` `8` → `8` (unchanged, this unit has 8 lessons).

- [ ] **Step 7: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Okuma anlama exam unit with 40 questions, package version 7

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

If a planner test (`TodayPlanCoordinatorTests`) turns red, do **not** weaken it: those tests run with `.preview` access, so a red there means a new unit leaked into the free preview — fix the unit order instead.

---

## Task 3: Independent review — unit "Okuma anlama"

**Files:**
- Modify (only where defects are found): the eight files under `content/yds-academic-vocab-1/exam/reading/`, then regenerate both derived JSON files.

**Interfaces:**
- Consumes: Task 2's 40 questions and 8 passages.
- Produces: no code surface — a corrected bank plus a written verdict (`ok` / `fix` / `replace`).

- [ ] **Step 1: Run the shared "Review procedure"** (section above) over the eight reading lessons. Reading-specific checks: every question is answerable from its own passage alone; every "stated" claim in a key is really in the passage; no distractor is also supported by the passage; each vocabulary-in-context question has exactly one meaning that fits the sentence; passages are 170-280 words and do not repeat a domain.
- [ ] **Step 2: Commit any fixes (skip if none)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply content review fixes to the Okuma anlama exam unit

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 3: Push and confirm both CI workflows green**, then record the verdict.

---

## Task 4: Unit "Cloze ve cümle tamamlama" — 4 cloze + 4 sentence lessons, 72 questions

**Files:**
- Create: `content/yds-academic-vocab-1/exam/cloze-sentence/cloze-1.json` … `cloze-4.json`, `sentence-1.json` … `sentence-4.json`
- Modify: `scripts/assemble-content.py` (`EXAM_UNITS` second entry)
- Regenerate: both derived JSON files
- Modify: the three test files (numbers below)

**Interfaces:**
- Consumes: Task 1's lint, Task 2's table and tests.
- Produces: unit `yds-exam-unit-cloze-sentence` at order 10 with lessons `yds-exam-cloze-1..4` then `yds-exam-sentence-1..4`.

### Lesson inventory (contractual)

| order | file | lesson id | title | headword | freqRank | min | questions | topic / focus |
|---|---|---|---|---|---|---|---|---|
| 0 | `cloze-1.json` | `yds-exam-cloze-1` | `Cloze Test: Mikrofinans` | `Cloze: Microfinance` | 3010 | 10 | 8 | connectors, prepositions, relatives |
| 1 | `cloze-2.json` | `yds-exam-cloze-2` | `Cloze Test: Çift Dilli Eğitim` | `Cloze: Bilingual Education` | 3011 | 10 | 8 | verb forms, quantifiers, vocabulary |
| 2 | `cloze-3.json` | `yds-exam-cloze-3` | `Cloze Test: Okyanus Plastikleri` | `Cloze: Ocean Plastics` | 3012 | 10 | 8 | mixed, collocations |
| 3 | `cloze-4.json` | `yds-exam-cloze-4` | `Cloze Test: Gen Düzenleme Etiği` | `Cloze: Ethics of Gene Editing` | 3013 | 10 | 8 | mixed, harder connectors/tense |
| 4 | `sentence-1.json` | `yds-exam-sentence-1` | `Cümle Tamamlama 1: Neden ve Sonuç` | `Sentence Completion: Cause and Result` | 3020 | 9 | 10 | cause, result, contrast |
| 5 | `sentence-2.json` | `yds-exam-sentence-2` | `Cümle Tamamlama 2: Koşul ve Karşıtlık` | `Sentence Completion: Condition and Concession` | 3021 | 9 | 10 | conditions, concession |
| 6 | `sentence-3.json` | `yds-exam-sentence-3` | `Cümle Tamamlama 3: Zaman ve Amaç` | `Sentence Completion: Time and Purpose` | 3022 | 9 | 10 | sequence, purpose, participles |
| 7 | `sentence-4.json` | `yds-exam-sentence-4` | `Cümle Tamamlama 4: İnce Ayrımlar` | `Sentence Completion: Fine Distinctions` | 3023 | 9 | 10 | exception, comparison, emphasis |

Cloze lessons: passage 170-260 words carrying blanks `(1)----` … `(8)----`; question `k`'s stem is the sentence containing `(k) ----`; options are single words or short phrases; skill `reading`, kind `cloze`. Sentence lessons: skill `grammar`, kind `sentenceCompletion`, no passage, one `----` per stem, options are clause completions. Sentence lessons must not repeat the 7a `yds-practice-lesson-sentence-1` stems.

`definition`: cloze `"<konu> üzerine sekiz boşluklu bir cloze testi; <odak>."`; sentence `"<odak> ilişkisine dayanan on cümle tamamlama sorusu."`. Question ids as in the contract (`-q01` … `-q08` cloze, `-q10` sentence).

### Worked exemplars

**Cloze (passage excerpt shape — the real passage is 170-260 words with eight blanks written `(k)----`):**

```text
Microfinance institutions lend small sums to people who (1)---- normally be refused credit by commercial banks. ...
```

```json
{
  "id": "yds-exam-cloze-1-q01",
  "kind": "cloze",
  "order": 0,
  "prompt": "Microfinance institutions lend small sums to people who (1) ---- normally be refused credit by commercial banks.",
  "options": ["would", "did", "have", "were", "had"],
  "correctIndex": 0,
  "explanationTR": "«normally» alışkanlık ve genel durum bildirir; kip fiili would, reddedilme ihtimalini genel bir durum olarak verir. (B) did ve (C) have kip yardımcı değildir ve «be refused» ile birleşmez. (D) were ile «be refused» çift be fiili yapar. (E) had, «be refused» ile geçmiş zaman kalıbı kurmaz.",
  "passageID": "yds-exam-passage-cloze-1"
}
```

**Sentence:**

```json
{
  "id": "yds-exam-sentence-2-q01",
  "kind": "sentenceCompletion",
  "order": 0,
  "prompt": "Had the regulator intervened sooner, ----.",
  "options": [
    "the bank might have avoided its eventual collapse",
    "the bank might avoid its eventual collapse next year",
    "the bank would have been collapsing for several years",
    "the regulator will have intervened much earlier",
    "the collapse of the bank has been avoided already"
  ],
  "correctIndex": 0,
  "explanationTR": "«Had + özne + V3» üçüncü tip koşuldur; ana cümle would/might have + V3 ister: (A). (B) şimdiki ve gelecek zamanlıdır. (C) sürerlik anlamı katar ve mantığı bozar. (D) ve (E) üçüncü tip koşul kalıbını kurmaz.",
  "passageID": null
}
```

### Steps

- [ ] **Step 1: Author the eight files** with the helper (`unit_dir="cloze-sentence"`, cloze `minutes=10, skill="reading", kind="cloze"`, sentence `minutes=9, skill="grammar", kind="sentenceCompletion"`). Cloze passages first (distinct domains: development finance, education, marine environment, bioethics), blanks `(1)----`…`(8)----`, then their eight questions each. Cloze keys per lesson: for eight questions use `[1, 3, 0, 4, 2, 1, 3, 0]`-style plans (each key at most three times, never three in a row); sentence lessons: for ten questions each key at most four times.
- [ ] **Step 2: Register the unit** — append to `EXAM_UNITS`, after the reading entry:

```python
    {
        "id": "yds-exam-unit-cloze-sentence",
        "theme": "Cloze ve cümle tamamlama",
        "order": 10,
        "files": [
            "cloze-sentence/cloze-1.json",
            "cloze-sentence/cloze-2.json",
            "cloze-sentence/cloze-3.json",
            "cloze-sentence/cloze-4.json",
            "cloze-sentence/sentence-1.json",
            "cloze-sentence/sentence-2.json",
            "cloze-sentence/sentence-3.json",
            "cloze-sentence/sentence-4.json",
        ],
    },
```

`PACKAGE_VERSION` stays 7.

- [ ] **Step 3: Regenerate with the real Python and check the diff**, expecting both derived files modified.
- [ ] **Step 4: Update the tests**
  - `ContentImporterTests.swift`: `package.units.count` → `11`; both item counts → `173`; `.practiceSet` → `21`; both question counts → `447`.
  - `RealContentSeedingTests.swift`: `package.units.count` → `11`; both `allItems.count` → `173`; questions → `447`; passages → `15`. In `test_bundledPackage_examUnits_areStructurallySound` replace the three unit lists and add the lesson-id list:

```swift
        XCTAssertEqual(examUnits.map(\.id), ["yds-exam-unit-reading", "yds-exam-unit-cloze-sentence"])
        XCTAssertEqual(examUnits.map(\.theme), ["Okuma anlama", "Cloze ve cümle tamamlama"])
        XCTAssertEqual(examUnits.map(\.order), [9, 10])
```

and after the `units[9]` assertion add:

```swift
        XCTAssertEqual(
            units[10].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-cloze-1", "yds-exam-cloze-2", "yds-exam-cloze-3", "yds-exam-cloze-4",
                "yds-exam-sentence-1", "yds-exam-sentence-2", "yds-exam-sentence-3", "yds-exam-sentence-4",
            ]
        )
```

  - `CoursePathViewModelTests.swift`: `sections.count` → `11`; `sections.last?.unitID` → `"yds-exam-unit-cloze-sentence"`; `sections.last?.tasks.count` → `8`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Cloze ve cümle tamamlama exam unit with 72 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 5: Independent review — unit "Cloze ve cümle tamamlama"

**Files:**
- Modify (only where defects are found): the eight files under `content/yds-academic-vocab-1/exam/cloze-sentence/`, then regenerate both derived JSON files.

- [ ] **Step 1: Run the shared "Review procedure"** over the four cloze and four sentence lessons. Cloze-specific checks: the passage reads naturally with the KEY in every blank simultaneously; each blank tests one thing; no two blanks are answerable from each other's options; the blank number in the stem matches the passage. Sentence-specific checks: stem + key is one natural sentence; exactly one option keeps the logical relation the stem sets up; none repeats a 7a sentence-completion stem.
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the Cloze ve cümle tamamlama exam unit` (same trailer and heredoc form as Task 3).
- [ ] **Step 3: Push and confirm both CI workflows green**, then record the verdict.

---

## Task 6: Unit "Paragraf soruları" — 3 paragraph + 3 irrelevant + 2 dialogue lessons, 64 questions

**Files:**
- Create: `content/yds-academic-vocab-1/exam/paragraph/paragraph-1.json` … `-3`, `irrelevant-1.json` … `-3`, `dialogue-1.json`, `dialogue-2.json`
- Modify: `scripts/assemble-content.py` (`EXAM_UNITS` third entry)
- Regenerate: both derived JSON files
- Modify: the three test files (numbers below)

**Interfaces:**
- Consumes: Task 1's lint and the earlier unit tasks' tests.
- Produces: unit `yds-exam-unit-paragraph` at order 11 with lessons `yds-exam-paragraph-1..3`, `yds-exam-irrelevant-1..3`, `yds-exam-dialogue-1..2`.

### Lesson inventory (contractual)

| order | file | lesson id | title | headword | freqRank | min | questions | focus |
|---|---|---|---|---|---|---|---|---|
| 0 | `paragraph-1.json` | `yds-exam-paragraph-1` | `Paragraf Tamamlama 1: Konu Cümlesi` | `Paragraph Completion: Topic Sentence` | 3030 | 10 | 8 | the missing sentence opens the paragraph |
| 1 | `paragraph-2.json` | `yds-exam-paragraph-2` | `Paragraf Tamamlama 2: Geçiş Cümlesi` | `Paragraph Completion: Transition` | 3031 | 10 | 8 | the missing sentence links two ideas |
| 2 | `paragraph-3.json` | `yds-exam-paragraph-3` | `Paragraf Tamamlama 3: Sonuç Cümlesi` | `Paragraph Completion: Conclusion` | 3032 | 10 | 8 | the missing sentence closes the paragraph |
| 3 | `irrelevant-1.json` | `yds-exam-irrelevant-1` | `Konu Dışı Cümle 1` | `Irrelevant Sentence 1` | 3040 | 9 | 8 | clear topic shift |
| 4 | `irrelevant-2.json` | `yds-exam-irrelevant-2` | `Konu Dışı Cümle 2` | `Irrelevant Sentence 2` | 3041 | 9 | 8 | related-but-off-focus detail |
| 5 | `irrelevant-3.json` | `yds-exam-irrelevant-3` | `Konu Dışı Cümle 3` | `Irrelevant Sentence 3` | 3042 | 9 | 8 | the odd sentence shares vocabulary with the paragraph |
| 6 | `dialogue-1.json` | `yds-exam-dialogue-1` | `Diyalog Tamamlama 1` | `Dialogue Completion 1` | 3050 | 8 | 8 | study and office-hours exchanges |
| 7 | `dialogue-2.json` | `yds-exam-dialogue-2` | `Diyalog Tamamlama 2` | `Dialogue Completion 2` | 3051 | 8 | 8 | workplace and service exchanges |

None of these lessons carries a passage. Skills and kinds: paragraph `reading`/`paragraphCompletion`; irrelevant `reading`/`irrelevantSentence`; dialogue `grammar`/`dialogueCompletion`. `definition`: paragraph `"Paragraftaki eksik cümleyi bulmaya dayanan sekiz soru; <odak>."`, irrelevant `"Paragrafın bütünlüğünü bozan cümleyi bulmaya dayanan sekiz soru."`, dialogue `"Diyalogdaki eksik konuşmayı tamamlamaya dayanan sekiz soru."`

### Question conventions

- **Paragraph:** a 3-4 sentence paragraph (60-110 words) with exactly one `----` in place of one sentence; the five options are complete candidate sentences of similar length; the key is the only one that fits the paragraph's logic, reference and register; each distractor fails for a nameable reason (topic shift, contradicts a neighbouring sentence, wrong reference, repeats an existing sentence, overgeneralises).
- **Irrelevant:** the stem is the instruction-free paragraph of five numbered sentences `(I)` … `(V)` (all five numerals present in the stem, 60-110 words in total); the options are exactly `I`, `II`, `III`, `IV`, `V`; the key is the one sentence that breaks the paragraph's unity; at most one lesson question per lesson may have the odd sentence at position `I`, and the answer position must vary so the key distribution passes.
- **Dialogue:** a two-speaker exchange (speaker names or labels such as `Student:` / `Professor:`) with exactly one `----` as one speaker's line; options are candidate lines; the key must respond to the previous line and lead to the next.

### Worked exemplars

**Paragraph:**

```json
{
  "id": "yds-exam-paragraph-1-q01",
  "kind": "paragraphCompletion",
  "order": 0,
  "prompt": "Urban planners increasingly argue that street trees are more than decoration. ---- Shaded pavements can be up to ten degrees cooler than exposed ones, and cooler streets encourage people to walk instead of drive. Over time, this shift can reduce both traffic and air pollution.",
  "options": [
    "Trees cool the air around them, and that cooling has consequences well beyond comfort.",
    "Many cities choose the species that are cheapest to buy and easiest to prune.",
    "Trees have no measurable effect on the temperature of the streets they line.",
    "The first public parks in Europe were laid out several centuries ago.",
    "Walking through crowded streets is generally considered dangerous and unpleasant."
  ],
  "correctIndex": 0,
  "explanationTR": "Sonraki cümleler gölgeli kaldırımların serinliğinden ve bunun yürümeyi teşvik etmesinden söz ediyor; bu zinciri kuran tek cümle (A). (B) maliyet ve budama konusuna kayar. (C) ağaçların etkisiz olduğunu söyler ve sonraki cümlelerle çelişir. (D) tarihsel bir ayrıntıdır, konuyla bağı yoktur. (E) yürümenin tehlikeli olduğunu iddia eder, oysa paragraf yürümeyi olumlu gösterir.",
  "passageID": null
}
```

**Irrelevant sentence:**

```json
{
  "id": "yds-exam-irrelevant-1-q01",
  "kind": "irrelevantSentence",
  "order": 0,
  "prompt": "(I) Coral reefs cover less than one per cent of the ocean floor. (II) They nevertheless support roughly a quarter of all marine species. (III) Many tourists travel to tropical coasts specifically to go diving. (IV) The complex structure of a reef provides shelter and breeding grounds for thousands of organisms. (V) For this reason, the loss of a reef often triggers a collapse of the fish populations around it.",
  "options": ["I", "II", "III", "IV", "V"],
  "correctIndex": 2,
  "explanationTR": "Paragraf, resiflerin ekolojik önemini ve kaybının sonuçlarını anlatıyor. (III) turistlerin dalış tercihinden söz eder, bu ekolojik akışa bağlanmaz. (I) resiflerin küçük alanını, (II) yine de taşıdığı tür zenginliğini, (IV) barınak işlevini, (V) ise kayıp sonucunu verir; hepsi ana fikri destekler.",
  "passageID": null
}
```

**Dialogue:**

```json
{
  "id": "yds-exam-dialogue-1-q01",
  "kind": "dialogueCompletion",
  "order": 0,
  "prompt": "Student: Professor, I couldn't finish the survey analysis before the deadline.\nProfessor: ----\nStudent: I'll send you the revised draft by Friday.",
  "options": [
    "That's understandable, but please tell me earlier next time if you expect a delay.",
    "Then I'll assume you have already submitted the final draft.",
    "The deadline was extended because most students finished early.",
    "You should have analysed the survey before it was even conducted.",
    "In that case, no further work is required for this course."
  ],
  "correctIndex": 0,
  "explanationTR": "Öğrenci gecikmeyi kabul edip düzeltilmiş taslağı Cuma günü göndereceğini söylüyor; buna doğal yanıt, anlayış gösterip bir dahaki sefere önceden haber istemektir: (A). (B) teslim edildiğini varsayar, oysa öğrenci teslim etmedi. (C) uzatma olduğunu söyler ve öğrencinin cevabıyla uyuşmaz. (D) anlamsız bir eleştiridir. (E) ise ek işin gerekmediğini söyler ve öğrencinin taslak sözüyle çelişir.",
  "passageID": null
}
```

### Steps

- [ ] **Step 1: Author the eight files** with the helper (`unit_dir="paragraph"`). Irrelevant lessons: options are always `["I","II","III","IV","V"]`, so build them with `Q` by passing the four other numerals as `distractors` in numeral order and `key` as the odd sentence's index (for example correct `"III"`, distractors `["I","II","IV","V"]`, key `2`). Plan keys so no numeral is the answer more than three times per eight questions and never three in a row.
- [ ] **Step 2: Register the unit** — append to `EXAM_UNITS`:

```python
    {
        "id": "yds-exam-unit-paragraph",
        "theme": "Paragraf soruları",
        "order": 11,
        "files": [
            "paragraph/paragraph-1.json",
            "paragraph/paragraph-2.json",
            "paragraph/paragraph-3.json",
            "paragraph/irrelevant-1.json",
            "paragraph/irrelevant-2.json",
            "paragraph/irrelevant-3.json",
            "paragraph/dialogue-1.json",
            "paragraph/dialogue-2.json",
        ],
    },
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**, expecting both derived files modified.
- [ ] **Step 4: Update the tests**
  - `ContentImporterTests.swift`: `package.units.count` → `12`; both item counts → `181`; `.practiceSet` → `29`; both question counts → `511`.
  - `RealContentSeedingTests.swift`: `package.units.count` → `12`; both `allItems.count` → `181`; questions → `511`; passages stay `15`. In the exam structure test the lists become:

```swift
        XCTAssertEqual(
            examUnits.map(\.id),
            ["yds-exam-unit-reading", "yds-exam-unit-cloze-sentence", "yds-exam-unit-paragraph"]
        )
        XCTAssertEqual(examUnits.map(\.theme), ["Okuma anlama", "Cloze ve cümle tamamlama", "Paragraf soruları"])
        XCTAssertEqual(examUnits.map(\.order), [9, 10, 11])
```

  and after the `units[10]` assertion add:

```swift
        XCTAssertEqual(
            units[11].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-paragraph-1", "yds-exam-paragraph-2", "yds-exam-paragraph-3",
                "yds-exam-irrelevant-1", "yds-exam-irrelevant-2", "yds-exam-irrelevant-3",
                "yds-exam-dialogue-1", "yds-exam-dialogue-2",
            ]
        )
```

  - `CoursePathViewModelTests.swift`: `sections.count` → `12`; `sections.last?.unitID` → `"yds-exam-unit-paragraph"`; `sections.last?.tasks.count` → `8`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Paragraf soruları exam unit with 64 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 7: Independent review — unit "Paragraf soruları"

**Files:**
- Modify (only where defects are found): the eight files under `content/yds-academic-vocab-1/exam/paragraph/`, then regenerate both derived JSON files.

- [ ] **Step 1: Run the shared "Review procedure"** over the eight lessons. Type-specific checks: **paragraph** — fill each blank with every option and confirm exactly one keeps reference, logic and register; **irrelevant** — read each five-sentence paragraph twice and confirm exactly one sentence is off-topic while the other four form a coherent chain (if two sentences could be argued off-topic, or none, it is a `replace`); **dialogue** — every option is a natural line, exactly one answers the previous speaker AND prepares the next.
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the Paragraf soruları exam unit` (same trailer and heredoc form as Task 3).
- [ ] **Step 3: Push and confirm both CI workflows green**, then record the verdict.

---

## Task 8: Unit "Çeviri ve yeniden ifade" — 3 EN→TR + 3 TR→EN + 3 restatement lessons, 72 questions

**Files:**
- Create: `content/yds-academic-vocab-1/exam/translation-restatement/translation-en-tr-1.json` … `-3`, `translation-tr-en-1.json` … `-3`, `restatement-1.json` … `-3`
- Modify: `scripts/assemble-content.py` (`EXAM_UNITS` fourth entry)
- Regenerate: both derived JSON files
- Modify: the three test files (numbers below)

**Interfaces:**
- Consumes: Task 1's lint and the earlier unit tasks' tests.
- Produces: unit `yds-exam-unit-translation-restatement` at order 12; after this task the package is complete: 13 units, 82 lessons, 190 items, 583 questions.

### Lesson inventory (contractual)

| order | file | lesson id | title | headword | freqRank | min | questions |
|---|---|---|---|---|---|---|---|
| 0 | `translation-en-tr-1.json` | `yds-exam-translation-en-tr-1` | `Çeviri: İngilizce-Türkçe 1` | `Translation EN-TR 1` | 3060 | 9 | 8 |
| 1 | `translation-en-tr-2.json` | `yds-exam-translation-en-tr-2` | `Çeviri: İngilizce-Türkçe 2` | `Translation EN-TR 2` | 3061 | 9 | 8 |
| 2 | `translation-en-tr-3.json` | `yds-exam-translation-en-tr-3` | `Çeviri: İngilizce-Türkçe 3` | `Translation EN-TR 3` | 3062 | 9 | 8 |
| 3 | `translation-tr-en-1.json` | `yds-exam-translation-tr-en-1` | `Çeviri: Türkçe-İngilizce 1` | `Translation TR-EN 1` | 3070 | 9 | 8 |
| 4 | `translation-tr-en-2.json` | `yds-exam-translation-tr-en-2` | `Çeviri: Türkçe-İngilizce 2` | `Translation TR-EN 2` | 3071 | 9 | 8 |
| 5 | `translation-tr-en-3.json` | `yds-exam-translation-tr-en-3` | `Çeviri: Türkçe-İngilizce 3` | `Translation TR-EN 3` | 3072 | 9 | 8 |
| 6 | `restatement-1.json` | `yds-exam-restatement-1` | `Yeniden İfade 1` | `Restatement 1` | 3080 | 9 | 8 |
| 7 | `restatement-2.json` | `yds-exam-restatement-2` | `Yeniden İfade 2` | `Restatement 2` | 3081 | 9 | 8 |
| 8 | `restatement-3.json` | `yds-exam-restatement-3` | `Yeniden İfade 3` | `Restatement 3` | 3082 | 9 | 8 |

Skill `reading`; kinds `translation` (both directions) and `restatement`; no passages. `definition`: `"İngilizce cümlelerin Türkçe karşılığını seçmeye dayanan sekiz çeviri sorusu."`, `"Türkçe cümlelerin İngilizce karşılığını seçmeye dayanan sekiz çeviri sorusu."`, `"Bir cümlenin anlamını koruyan yeniden ifadesini seçmeye dayanan sekiz soru."` The three lessons of a type escalate in difficulty: lesson 1 straightforward sentences, lesson 2 conditionals, passives and relative clauses, lesson 3 inversion, subjunctive, nominal clauses and idiomatic academic phrasing. Sentences are 18-40 words, academic register, no sentence reused from the 7a translation lesson (`yds-practice-lesson-translation-1`).

### Question conventions

- **EN→TR:** the stem is an English sentence; the five options are Turkish translations of similar length; the key preserves tense, modality, negation, agent and every qualifier; each distractor changes exactly one such element (tense/modality, negation or scope, subject/agent, a qualifier or connector, or a reversed relation) so it is refutable in one sentence. Turkish is natural written Turkish, not calque.
- **TR→EN:** the stem is a Turkish sentence; the five options are English sentences; same rules mirrored (tense, voice, connector, article/quantifier, preposition).
- **Restatement:** the stem is one sentence; each of the five options is a sentence; exactly one preserves the meaning; distractors reverse a condition, change a quantifier or modality, or shift cause and effect.

### Worked exemplars

**EN→TR:**

```json
{
  "id": "yds-exam-translation-en-tr-3-q01",
  "kind": "translation",
  "order": 0,
  "prompt": "Rarely do policymakers acknowledge that a measure they introduced has had consequences that no one intended.",
  "options": [
    "Politika yapıcılar, uyguladıkları bir önlemin kimsenin istemediği sonuçlar doğurduğunu nadiren kabul eder.",
    "Politika yapıcılar, uyguladıkları önlemlerin kimsenin istemediği sonuçlar doğurmasını sık sık kabul eder.",
    "Politika yapıcıların uyguladığı önlemler, nadiren de olsa istenen sonuçları doğurmuştur.",
    "Kimsenin istemediği sonuçlar doğuran önlemleri politika yapıcılar hemen geri çeker.",
    "Politika yapıcılar, önlemlerin sonuçlarını daha önce kimsenin bilmediğini nadiren kabul eder."
  ],
  "correctIndex": 0,
  "explanationTR": "«Rarely do ...» devrik yapısı «nadiren» demektir ve fiil sıklığı olumsuzlar; «had consequences that no one intended» ise «kimsenin istemediği sonuçlar doğurduğunu» verir: (A). (B) sıklığı tersine çevirip «sık sık» der. (C) sonuçların istenen sonuçlar olduğunu söyler. (D) önlemlerin hemen geri çekildiğini ekler, metinde yok. (E) bilgi eksikliğini anlatır, istenmeyen sonucu değil.",
  "passageID": null
}
```

**TR→EN:**

```json
{
  "id": "yds-exam-translation-tr-en-1-q01",
  "kind": "translation",
  "order": 0,
  "prompt": "Hükümetin açıkladığı yeni teşvikler, küçük işletmelerin ihracat yapmasını kolaylaştırmayı amaçlıyor.",
  "options": [
    "The new incentives announced by the government are intended to make it easier for small businesses to export.",
    "The new incentives announced by the government have made it impossible for small businesses to export.",
    "The government announced that small businesses would export the new incentives.",
    "The new incentives aim to help the government export more to small businesses.",
    "Small businesses announced new incentives that would make exporting easier for the government."
  ],
  "correctIndex": 0,
  "explanationTR": "«Açıkladığı yeni teşvikler» = the new incentives announced by the government; «amaçlıyor» = are intended to; «kolaylaştırmayı» = make it easier: (A). (B) ihracatı imkânsız kılar, anlam tersine döner. (C) teşviklerin ihraç edildiğini söyler. (D) ve (E) özneleri karıştırır: ihracat yapan küçük işletmelerdir, hükümet değil.",
  "passageID": null
}
```

**Restatement:**

```json
{
  "id": "yds-exam-restatement-1-q01",
  "kind": "restatement",
  "order": 0,
  "prompt": "Unless the board reverses its decision, the university will lose its accreditation.",
  "options": [
    "The university will lose its accreditation if the board does not reverse its decision.",
    "The board will reverse its decision only if the university loses its accreditation.",
    "Although the board reverses its decision, the university will still lose its accreditation.",
    "The university lost its accreditation because the board reversed its decision.",
    "Whether or not the board reverses its decision, accreditation will be kept."
  ],
  "correctIndex": 0,
  "explanationTR": "«Unless» = «if ... not»: kurul kararı geri almazsa üniversite akreditasyonu kaybeder, bu da (A). (B) koşul ve sonucu yer değiştirir. (C) karşıtlık kurar ve geri alma durumunda bile kayıp der. (D) geçmiş zaman ve yanlış neden-sonuç kurar. (E) akreditasyonun korunacağını söyler, oysa cümle kaybı öngörüyor.",
  "passageID": null
}
```

### Steps

- [ ] **Step 1: Author the nine files** with the helper (`unit_dir="translation-restatement"`, `minutes=9`, `skill="reading"`, kinds as above). Plan eight keys per lesson, for example `[2, 0, 3, 1, 4, 2, 0, 3]` and rotations, each key at most three times and never three in a row.
- [ ] **Step 2: Register the unit** — append to `EXAM_UNITS`:

```python
    {
        "id": "yds-exam-unit-translation-restatement",
        "theme": "Çeviri ve yeniden ifade",
        "order": 12,
        "files": [
            "translation-restatement/translation-en-tr-1.json",
            "translation-restatement/translation-en-tr-2.json",
            "translation-restatement/translation-en-tr-3.json",
            "translation-restatement/translation-tr-en-1.json",
            "translation-restatement/translation-tr-en-2.json",
            "translation-restatement/translation-tr-en-3.json",
            "translation-restatement/restatement-1.json",
            "translation-restatement/restatement-2.json",
            "translation-restatement/restatement-3.json",
        ],
    },
```

- [ ] **Step 3: Regenerate with the real Python and check the diff**, expecting both derived files modified.
- [ ] **Step 4: Update the tests**
  - `ContentImporterTests.swift`: `package.units.count` → `13`; both item counts → `190`; `.practiceSet` → `38`; both question counts → `583`.
  - `RealContentSeedingTests.swift`: `package.units.count` → `13`; both `allItems.count` → `190`; questions → `583`; passages stay `15`. In the exam structure test the lists become:

```swift
        XCTAssertEqual(
            examUnits.map(\.id),
            [
                "yds-exam-unit-reading", "yds-exam-unit-cloze-sentence",
                "yds-exam-unit-paragraph", "yds-exam-unit-translation-restatement",
            ]
        )
        XCTAssertEqual(
            examUnits.map(\.theme),
            ["Okuma anlama", "Cloze ve cümle tamamlama", "Paragraf soruları", "Çeviri ve yeniden ifade"]
        )
        XCTAssertEqual(examUnits.map(\.order), [9, 10, 11, 12])
```

  and after the `units[11]` assertion add:

```swift
        XCTAssertEqual(
            units[12].lessons.sorted { $0.order < $1.order }.map(\.id),
            [
                "yds-exam-translation-en-tr-1", "yds-exam-translation-en-tr-2", "yds-exam-translation-en-tr-3",
                "yds-exam-translation-tr-en-1", "yds-exam-translation-tr-en-2", "yds-exam-translation-tr-en-3",
                "yds-exam-restatement-1", "yds-exam-restatement-2", "yds-exam-restatement-3",
            ]
        )
```

  - `CoursePathViewModelTests.swift`: `sections.count` → `13`; `sections.last?.unitID` → `"yds-exam-unit-translation-restatement"`; `sections.last?.tasks.count` → `9`.
- [ ] **Step 5: Commit, push, confirm both CI workflows green**

```bash
git add content scripts/assemble-content.py App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests App/Tests
git commit -m "$(cat <<'EOF'
Add the Çeviri ve yeniden ifade exam unit with 72 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
bash scripts/ci-test.sh
bash scripts/ci-app-build.sh
```

---

## Task 9: Independent review — unit "Çeviri ve yeniden ifade"

**Files:**
- Modify (only where defects are found): the nine files under `content/yds-academic-vocab-1/exam/translation-restatement/`, then regenerate both derived JSON files.

- [ ] **Step 1: Run the shared "Review procedure"** over the nine lessons. Type-specific checks: **translation** — verify each key preserves tense, modality, negation, voice and every qualifier, and that each distractor is wrong for exactly one nameable reason (a distractor that is a defensible alternative translation is a defect); Turkish must be natural, not a calque; no sentence is reused from `yds-practice-lesson-translation-1`. **Restatement** — for each stem, check that exactly one option preserves the meaning under every reading and that no distractor is a valid paraphrase (conditionals, quantifiers and modality are the usual leaks).
- [ ] **Step 2: Commit any fixes (skip if none)** with the message `Apply content review fixes to the Çeviri ve yeniden ifade exam unit` (same trailer and heredoc form as Task 3).
- [ ] **Step 3: Push and confirm both CI workflows green**, then record the verdict.

---

## Task 10: Whole-branch review and close

**Files:**
- Modify (only where defects are found): any file under `content/yds-academic-vocab-1/exam/`, then regenerate both derived JSON documents.
- Read-only: `scripts/assemble-content.py`, the three test files.

This is a cross-unit gate: it looks for what a per-unit review cannot see (duplicate stems across all 583 questions, passages that share a topic, a rule taught inconsistently, an exam question that repeats a 7b grammar question).

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
exam = [l for l in lessons if l["id"].startswith("yds-exam-")]
print("version", pkg["version"])
print("units", len(pkg["units"]), [(u["order"], u["theme"]) for u in pkg["units"][9:]])
print("lessons", len(lessons), "exam lessons", len(exam))
print("items", sum(len(l["items"]) for l in lessons))
print("questions", len(questions), "exam questions", sum(len(l["questions"]) for l in exam))
print("passages", sum(1 for l in lessons if "passage" in l))
prompts = {}
for q in questions:
    prompts.setdefault(q["prompt"].strip().lower(), []).append(q["id"])
dup = {p: ids for p, ids in prompts.items() if len(ids) > 1}
print("duplicate prompts:", dup if dup else "none")
PY
rm -rf scripts/__pycache__
```

Expected, exactly: `version 7`, `units 13`, `lessons 82 exam lessons 33`, `items 190`, `questions 583 exam questions 248`, `passages 15`, `duplicate prompts: none`; `git status` clean. Any duplicate prompt is a defect — rewrite one of the two questions.

- [ ] **Step 2: Cross-unit spot check (fresh reviewer, not an author)**

Pick 30 questions at random across the four exam units (at least six per unit, at least one of every lesson type), solve each cold, compare with `correctIndex`. Also: read all 12 passages' titles and openings for topic overlap with each other and with the three 7a passages; scan the 33 exam lessons for a question whose stem repeats a 7b grammar question's idea with the same key; run a script that checks the `(A)`-`(E)` letters in every `explanationTR` against the option at that index (option text quoted right after the letter must match, or the grouped-letter form must be consistent). Any disagreement is a defect: fix at source, regenerate, note it. Two or more disagreements in one unit means that unit's review gate was not applied properly — re-open that unit's review task instead of patching here.

- [ ] **Step 3: Confirm the spec's acceptance criteria one by one**

Record each against the shipped package:
- four units at orders 9-12 with the exact themes `Okuma anlama`, `Cloze ve cümle tamamlama`, `Paragraf soruları`, `Çeviri ve yeniden ifade`;
- 33 lessons in the contractual shapes (`test_bundledPackage_examUnits_areStructurallySound`);
- the four new kinds are imported and no other question kind or importer behaviour changed;
- package version 7, every pre-existing id unchanged (`RealContentSeedingTests`, `ContentImporterTests`);
- the free preview still shows exactly the first unit's 3 vocabulary + 7 practice lessons and nothing else (`test_dersYolu_previewUser_seesOnlyTheFirstUnit_andEveryGrammarUnitIsLocked` passes with only its counts and unit id changed);
- no access-policy or purchase-flow change (`git diff` of `App/Sources` shows no change from this slice).

- [ ] **Step 4: Commit any fixes (skip if none)**

```bash
git add content App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
git commit -m "$(cat <<'EOF'
Apply whole-branch review fixes to the YDS exam question types

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

- [ ] **Step 6: Record the known gap and continue the roadmap**

Record that the practice screens render the four new kinds through the unchanged generic view, which CI cannot exercise: a reading lesson, a cloze lesson and an irrelevant-sentence lesson go on the TestFlight checklist in `docs/store-setup.md` (add three checkbox lines under section 3). Update `Desktop\ENGLISH_KALANLAR.txt`. Then start Slice 7d (vocabulary expansion and study techniques) with `superpowers:brainstorming`. Integration of the branch stays the user's decision.

---

## Self-review

**1. Spec coverage.**

| Spec requirement | Task |
|---|---|
| Four new question kinds | 1 |
| `EXAM_UNITS` table, loader, lint (shapes, naming, cloze markers, irrelevant options, one `----`), version 7 | 1, 2 |
| Unit "Okuma anlama": 8 reading lessons, 40 questions, 8 passages | 2 (authoring), 3 (review) |
| Unit "Cloze ve cümle tamamlama": 4 cloze + 4 sentence, 72 questions, 4 passages | 4, 5 |
| Unit "Paragraf soruları": 3 paragraph + 3 irrelevant + 2 dialogue, 64 questions | 6, 7 |
| Unit "Çeviri ve yeniden ifade": 3 EN→TR + 3 TR→EN + 3 restatement, 72 questions | 8, 9 |
| Locked units, free preview unchanged | Preview test updated in 2, 4, 6, 8; checked in 10 |
| Same quality bar and independent per-unit review | Global Constraints, "Review procedure", Tasks 3, 5, 7, 9 |
| Totals and structure tests | Running-totals table; tests in 2, 4, 6, 8 |
| Known gap: new kinds on the generic screen | Task 10 step 6 |
| Strategy cards deferred to 7d | Spec decision 6 (no task; 7d) |

**2. Placeholder scan.** No "TBD"/"TODO"; every code step carries its code. The content tasks specify the inventories, scopes, conventions and exemplars; the questions themselves are authored to those contracts and verified by the lint plus the independent review, as in 7b.

**3. Type consistency.** `EXAM_LESSON_SHAPE`, `EXAM_UNITS`, `EXAM_LESSON_ID_PREFIX`, `validate_exam_lesson`, `load_exam_units` are named identically in Tasks 1-10. Lesson ids, card ids, passage ids and question ids follow the one naming contract everywhere. The Swift test names (`test_bundledPackage_examUnits_areStructurallySound`, `examShapes`) are defined once in Task 2 and only extended afterwards. Running totals: units 10/11/12/13, lessons 57/65/73/82, items 165/173/181/190, `practiceSet` 13/21/29/38, questions 375/447/511/583, passages 11/15/15/15.
