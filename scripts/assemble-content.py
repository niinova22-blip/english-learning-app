#!/usr/bin/env python3
"""Assemble the YDS Academic Vocabulary I content package from its source
batch files and write it to both places the app/tests need it.

This exists because the 120-item YDS package is authored as 4 separate
batch files under content/yds-academic-vocab-1/batches/ (one per unit) but
is consumed as a single assembled JSON document in two places:

  - App/Sources/EnglishApp/Resources/YDSAcademicVocabulary1.json (shipped
    app resource, bundled by App/project.yml)
  - LearningEngine/Tests/LearningEngineTests/Fixtures/YDSAcademicVocabulary1.json
    (test fixture used by ContentImporterTests)

Previously that assembly was done by hand, which is what caused a real bug
(UTF-8-as-Windows-1252 double-encoding of Turkish characters in 91 of 120
items, fixed in a prior commit). This script is the repeatable replacement
for that manual step, and CI runs it and diffs the result against what's
committed to catch any future drift between source and derived files.

The script also stamps the package `version` and `skillWeights`, and
derives each lesson's `title` and defaults its `skill` (a batch lesson may
still set `title`/`skill` explicitly to override the derived value).
Bumping `PACKAGE_VERSION` makes installed apps re-import the package on
next launch.

Usage:
    python3 scripts/assemble-content.py

All file I/O is explicit UTF-8, and output uses LF line endings regardless
of platform (important since this is routinely run on Windows).
"""
import json
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BATCH_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "batches")

# Unit order matches the package's intended lesson progression (0-3).
BATCH_FILES = [
    "business-economics.json",
    "science-research.json",
    "law-policy-society.json",
    "academic-writing.json",
]

# The seven Slice 7a practice lessons. They are appended to the FIRST unit
# (order 0) on purpose: LessonAccessPolicy exposes only the lowest-ordered
# unit to a preview user, so a separate practice unit would be permanently
# locked, and making practice the first unit would push every vocabulary
# lesson out of the free preview and kill the review loop.
PRACTICE_UNIT_ID = "yds-vocab1-unit-business-economics"
PRACTICE_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "practice")
PRACTICE_FILES = [
    "grammar-tenses.json",
    "grammar-conditionals.json",
    "reading-climate-policy.json",
    "reading-digital-economy.json",
    "cloze-urbanisation.json",
    "sentence-completion-1.json",
    "translation-1.json",
]

QUESTION_KINDS = {
    "grammar", "reading", "cloze", "sentenceCompletion", "translation",
    "paragraphCompletion", "irrelevantSentence", "dialogueCompletion", "restatement", "strategy",
}
PRACTICE_CARD_TYPES = {"grammarPoint", "practiceSet"}

GRAMMAR_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "grammar")

# Slice 7b grammar units, emitted after the four vocabulary units (orders
# 0-3). Each entry's `files` are relative to GRAMMAR_DIR and hold ONE lesson
# document each, without an `order` key: position in the list is the lesson
# order, restarting at 0 in every unit. The table is filled in unit by unit;
# an empty table leaves the derived JSON byte-identical.
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
]

GRAMMAR_LESSON_ID_PREFIX = "yds-grammar-"
GRAMMAR_LESSON_ID_RE = re.compile(r"^yds-grammar-[a-z0-9-]+-(1|2)$")
# lesson suffix -> (exact question count, exact estimatedDurationMinutes).
# Exact, not minimum: a short batch must never ship silently.
GRAMMAR_LESSON_SHAPE = {"1": (8, 8), "2": (10, 10)}
# No key may be used for more than this share of one file's questions.
MAX_KEY_SHARE = 0.4

EXAM_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "exam")

# Slice 7c exam-type units, emitted after the grammar units (orders 9-12).
# Same contract as GRAMMAR_UNITS: `files` are relative to EXAM_DIR, one lesson
# document per file without an `order` key; list position is the lesson order.
# An empty table leaves the derived JSON byte-identical.
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
]

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

TECH_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "tech")
# Slice 7d technique units (orders 13-15). Same contract as GRAMMAR_UNITS.
TECH_UNITS = [
    {
        "id": "yds-tech-unit-question-strategies",
        "theme": "Sınav soru tipi stratejileri",
        "order": 13,
        "files": [
            "question-strategies/reading.json", "question-strategies/cloze.json",
            "question-strategies/sentence.json", "question-strategies/translation.json",
            "question-strategies/paragraph.json", "question-strategies/irrelevant.json",
            "question-strategies/dialogue.json", "question-strategies/restatement.json",
            "question-strategies/vocabulary-questions.json", "question-strategies/grammar-questions.json",
        ],
    },
    {
        "id": "yds-tech-unit-exam-management",
        "theme": "Sınav yönetimi ve zaman",
        "order": 14,
        "files": [
            "exam-management/time-allocation.json", "exam-management/elimination.json",
            "exam-management/exam-day.json",
        ],
    },
    {
        "id": "yds-tech-unit-vocabulary-skills",
        "theme": "Kelime öğrenme teknikleri",
        "order": 15,
        "files": [
            "vocabulary-skills/prefixes.json", "vocabulary-skills/suffixes.json",
            "vocabulary-skills/context-clues.json", "vocabulary-skills/synonyms-collocations.json",
            "vocabulary-skills/memorisation.json",
        ],
    },
]
TECH_LESSON_ID_PREFIX = "yds-tech-"
# slug -> (question kind, lesson skill, exact question count, exact minutes)
TECH_LESSON_SHAPE = {
    "reading": ("strategy", "reading", 6, 7), "cloze": ("strategy", "reading", 6, 7),
    "sentence": ("strategy", "grammar", 6, 7), "translation": ("strategy", "reading", 6, 7),
    "paragraph": ("strategy", "reading", 6, 7), "irrelevant": ("strategy", "reading", 6, 7),
    "dialogue": ("strategy", "grammar", 6, 7), "restatement": ("strategy", "reading", 6, 7),
    "vocabulary-questions": ("strategy", "reading", 6, 7), "grammar-questions": ("strategy", "grammar", 6, 7),
    "time-allocation": ("strategy", "reading", 6, 7), "elimination": ("strategy", "reading", 6, 7),
    "exam-day": ("strategy", "reading", 6, 7),
    "prefixes": ("grammar", "grammar", 8, 9), "suffixes": ("grammar", "grammar", 8, 9),
    "context-clues": ("strategy", "reading", 8, 9), "synonyms-collocations": ("strategy", "reading", 8, 9),
    "memorisation": ("strategy", "reading", 8, 9),
}
TECH_CARD_TRAP_PHRASE = "En sık düşülen tuzak:"

VOCAB2_DIR = os.path.join(REPO_ROOT, "content", "yds-academic-vocab-1", "vocab2")
# Slice 7d vocabulary units (orders 16-23): one unit document per file, in unit order.
VOCAB2_FILES = []
VOCAB2_LESSON_ID_PREFIX = "yds-vocab2-lesson-"
VOCAB2_LESSON_ID_RE = re.compile(r"^yds-vocab2-lesson-([a-z]+(?:-[a-z]+)*)-([1-6])$")
VOCAB2_HEADWORD_RE = re.compile(r"^[a-z]+(?:-[a-z]+)*$")
VOCAB2_ITEM_KEYS = {
    "id", "type", "headword", "frequencyRank", "baseDifficulty", "definition",
    "exampleSentences", "translationTR", "collocations",
}

OUTPUT_PATHS = [
    os.path.join(REPO_ROOT, "App", "Sources", "EnglishApp", "Resources", "YDSAcademicVocabulary1.json"),
    os.path.join(REPO_ROOT, "LearningEngine", "Tests", "LearningEngineTests", "Fixtures", "YDSAcademicVocabulary1.json"),
]

# 4: Slice 7a adds practice lessons (questions, passages, grammar topic
# explanations). Bumping this makes installed apps re-import the package.
# 5: Slice 7b adds the grammar curriculum units (orders 4-8). Bumping this
# makes installed apps re-import the package; every existing id is unchanged,
# so FSRS history survives the reseed.
# 6: Slice 8 stamps the package's App Store product id. Bumping this makes
# installed apps re-import the package so the new attribute is populated;
# every existing id is unchanged, so FSRS history survives the reseed.
# 7: Slice 7c adds the exam-type units (orders 9-12). Bumping this makes
# installed apps re-import the package; every existing id is unchanged, so
# FSRS history survives the reseed.
# 8: Slice 7d adds the study-technique and second vocabulary units (orders
# 13-23). Bumping this makes installed apps re-import the package; every
# existing id is unchanged, so FSRS history survives the reseed.
PACKAGE_VERSION = 8

# Skill weights for the YDS goal. YDS has no listening, speaking, writing or
# pronunciation section, so those are 0 and the planner never schedules them.
SKILL_WEIGHTS = {
    "vocabulary": 35,
    "grammar": 30,
    "reading": 35,
    "listening": 0,
    "writing": 0,
    "speaking": 0,
    "pronunciation": 0,
}

SKILLS = ["vocabulary", "grammar", "reading", "listening", "writing", "speaking", "pronunciation"]


def validate_weights(weights):
    keys = set(weights)
    missing = [s for s in SKILLS if s not in keys]
    unknown = sorted(keys - set(SKILLS))
    if missing or unknown:
        raise ValueError(f"skillWeights missing={missing} unknown={unknown}")
    if any(v < 0 for v in weights.values()):
        raise ValueError("skillWeights has a negative weight")
    if sum(weights.values()) <= 0:
        raise ValueError("skillWeights total must be > 0")


def enrich_lessons(unit):
    """Adds a derived title and a default skill to every lesson, with a
    stable key order so the committed JSON diff stays readable. `passage`
    and `questions` are emitted only when present, so the twelve existing
    vocabulary lessons serialize byte-identically to before."""
    enriched = []
    for lesson in unit["lessons"]:
        skill = lesson.get("skill", "vocabulary")
        if skill not in SKILLS:
            raise ValueError(f"lesson {lesson['id']} has invalid skill {skill!r}")
        title = lesson.get("title", f"{unit['theme']} · {lesson['order'] + 1}")
        out = {
            "id": lesson["id"],
            "order": lesson["order"],
            "estimatedDurationMinutes": lesson["estimatedDurationMinutes"],
            "title": title,
            "skill": skill,
        }
        if "passage" in lesson:
            out["passage"] = lesson["passage"]
        out["items"] = lesson["items"]
        if lesson.get("questions"):
            out["questions"] = lesson["questions"]
        enriched.append(out)
    unit = dict(unit)
    unit["lessons"] = enriched
    return unit


def load_units():
    units = []
    for filename in BATCH_FILES:
        path = os.path.join(BATCH_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            units.append(json.load(f))
    return units


def load_practice_lessons():
    lessons = []
    for filename in PRACTICE_FILES:
        path = os.path.join(PRACTICE_DIR, filename)
        with open(path, "r", encoding="utf-8") as f:
            lessons.append(json.load(f))
    return lessons


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


def load_tech_units():
    """Builds the Slice 7d technique units from TECH_UNITS (list position = lesson order)."""
    units = []
    for unit_spec in TECH_UNITS:
        lessons = []
        for order, filename in enumerate(unit_spec["files"]):
            with open(os.path.join(TECH_DIR, filename), "r", encoding="utf-8") as f:
                lesson = json.load(f)
            if not lesson["id"].startswith(TECH_LESSON_ID_PREFIX):
                raise ValueError(
                    f"technique lesson {lesson['id']} (from {filename}) must start with {TECH_LESSON_ID_PREFIX!r}"
                )
            lesson = dict(lesson)
            lesson["order"] = order
            lessons.append(lesson)
        units.append({"id": unit_spec["id"], "theme": unit_spec["theme"], "order": unit_spec["order"], "lessons": lessons})
    return units


def load_vocab2_units():
    """Loads the Slice 7d vocabulary unit documents from VOCAB2_FILES."""
    units = []
    for filename in VOCAB2_FILES:
        with open(os.path.join(VOCAB2_DIR, filename), "r", encoding="utf-8") as f:
            units.append(json.load(f))
    return units


def attach_practice_lessons(units):
    """Appends the practice lessons to PRACTICE_UNIT_ID, numbering them
    straight after that unit's existing lessons."""
    target = next((u for u in units if u["id"] == PRACTICE_UNIT_ID), None)
    if target is None:
        raise ValueError(f"practice unit {PRACTICE_UNIT_ID} not found")
    next_order = max((l["order"] for l in target["lessons"]), default=-1) + 1
    for offset, lesson in enumerate(load_practice_lessons()):
        lesson = dict(lesson)
        lesson["order"] = next_order + offset
        target["lessons"].append(lesson)
    return units


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


def validate_tech_lesson(lesson):
    """Shape rules for Slice 7d technique lessons, keyed off the lesson id prefix."""
    lesson_id = lesson["id"]
    slug = lesson_id[len(TECH_LESSON_ID_PREFIX):]
    if slug not in TECH_LESSON_SHAPE:
        raise ValueError(f"technique lesson id {lesson_id!r} has unknown slug {slug!r}")
    kind, skill, expected_questions, expected_minutes = TECH_LESSON_SHAPE[slug]
    if lesson["skill"] != skill:
        raise ValueError(f"technique lesson {lesson_id} must have skill {skill!r}, found {lesson['skill']!r}")
    if lesson["estimatedDurationMinutes"] != expected_minutes:
        raise ValueError(f"technique lesson {lesson_id} must have estimatedDurationMinutes {expected_minutes}")
    if "passage" in lesson:
        raise ValueError(f"technique lesson {lesson_id} must not carry a passage")
    if len(lesson["items"]) != 1 or lesson["items"][0]["type"] != "grammarPoint":
        raise ValueError(f"technique lesson {lesson_id} must own exactly one grammarPoint item")
    card = lesson["items"][0]
    if card["id"] != f"yds-tech-card-{slug}":
        raise ValueError(f"technique lesson {lesson_id}: card id {card['id']!r} must be 'yds-tech-card-{slug}'")
    if TECH_CARD_TRAP_PHRASE not in card.get("explanationTR", ""):
        raise ValueError(f"technique lesson {lesson_id}: card explanation must contain {TECH_CARD_TRAP_PHRASE!r}")
    questions = lesson.get("questions", [])
    if len(questions) != expected_questions:
        raise ValueError(
            f"technique lesson {lesson_id} must have exactly {expected_questions} questions, found {len(questions)}"
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
        if question.get("passageID") is not None:
            raise ValueError(f"question {qid} must have passageID null")


def _vocab2_stem(headword):
    return headword[:max(3, len(headword) - 3)]


def validate_vocab2_lesson(lesson):
    """Shape rules for Slice 7d vocabulary lessons, keyed off the lesson id prefix."""
    lesson_id = lesson["id"]
    if VOCAB2_LESSON_ID_RE.match(lesson_id) is None:
        raise ValueError(f"vocabulary lesson id {lesson_id!r} must look like yds-vocab2-lesson-<slug>-<1..6>")
    if lesson["estimatedDurationMinutes"] != 5:
        raise ValueError(f"vocabulary lesson {lesson_id} must have estimatedDurationMinutes 5")
    if lesson["skill"] != "vocabulary":
        raise ValueError(f"vocabulary lesson {lesson_id} must have skill 'vocabulary'")
    items = lesson["items"]
    if len(items) != 10:
        raise ValueError(f"vocabulary lesson {lesson_id} must have exactly 10 items, found {len(items)}")
    for item in items:
        headword = item["headword"]
        iid = item["id"]
        if set(item) != VOCAB2_ITEM_KEYS:
            raise ValueError(f"item {iid} must have exactly the keys {sorted(VOCAB2_ITEM_KEYS)}")
        if item["type"] != "vocabulary":
            raise ValueError(f"item {iid} must have type 'vocabulary'")
        if VOCAB2_HEADWORD_RE.match(headword) is None:
            raise ValueError(f"item {iid}: headword {headword!r} must be lowercase ASCII letters and hyphens")
        if iid != f"yds-vocab2-item-{headword}":
            raise ValueError(f"item id {iid!r} must be 'yds-vocab2-item-{headword}'")
        if not isinstance(item["frequencyRank"], int) or item["frequencyRank"] < 1:
            raise ValueError(f"item {iid}: frequencyRank must be a positive integer")
        if not 0.05 <= item["baseDifficulty"] <= 0.95:
            raise ValueError(f"item {iid}: baseDifficulty must be within 0.05-0.95")
        definition = item["definition"].strip()
        if not definition.endswith(".") or len(definition) < 15:
            raise ValueError(f"item {iid}: definition must be a Turkish sentence ending with a full stop")
        if not item["translationTR"].strip():
            raise ValueError(f"item {iid}: empty translationTR")
        stem = _vocab2_stem(headword)
        for label, values in (("exampleSentences", item["exampleSentences"]), ("collocations", item["collocations"])):
            if len(values) != 3 or any(not v.strip() for v in values):
                raise ValueError(f"item {iid}: {label} must hold exactly 3 non-empty strings")
            for value in values:
                if stem not in value.lower():
                    raise ValueError(f"item {iid}: {label} entry {value!r} must contain {stem!r}")


def validate_vocab2_unit(unit):
    """Per-unit rules: six lessons with a strictly rising mean difficulty."""
    lessons = sorted(unit["lessons"], key=lambda l: l["order"])
    if len(lessons) != 6:
        raise ValueError(f"vocabulary unit {unit['id']} must have exactly 6 lessons, found {len(lessons)}")
    means = [sum(i["baseDifficulty"] for i in l["items"]) / len(l["items"]) for l in lessons]
    if any(b <= a for a, b in zip(means, means[1:])):
        raise ValueError(
            f"vocabulary unit {unit['id']}: mean difficulty must rise across lessons, found {[round(m, 3) for m in means]}"
        )
    if means[0] > 0.40 or means[-1] < 0.70:
        raise ValueError(f"vocabulary unit {unit['id']}: lesson 1 mean must be <= 0.40 and lesson 6 mean >= 0.70")


def validate_content(package):
    """Mirrors ContentImporter's validation so authors get the failure here,
    on Windows, seconds after saving -- not half an hour later in macOS CI.
    Also enforces three things the importer cannot: package-wide unique item
    ids, package-wide unique passage ids, and unique question `order` within
    a lesson."""
    question_ids = set()
    item_ids = set()
    passage_ids = set()
    unit_ids = set()
    lesson_ids = set()
    headwords = set()

    orders = sorted(unit["order"] for unit in package["units"])
    if orders != list(range(len(package["units"]))):
        raise ValueError(f"unit orders must be 0..{len(package['units']) - 1} with no gaps, found {orders}")

    for unit in package["units"]:
        if unit["id"] in unit_ids:
            raise ValueError(f"duplicate unit id {unit['id']}")
        unit_ids.add(unit["id"])
        if unit["id"].startswith("yds-vocab2-unit-"):
            validate_vocab2_unit(unit)
        for lesson in unit["lessons"]:
            lesson_id = lesson["id"]
            if lesson_id in lesson_ids:
                raise ValueError(f"duplicate lesson id {lesson_id}")
            lesson_ids.add(lesson_id)
            questions = lesson.get("questions", [])
            for item in lesson["items"]:
                if item["id"] in item_ids:
                    raise ValueError(f"duplicate item id {item['id']}")
                item_ids.add(item["id"])
                if item["type"] == "vocabulary":
                    key = item["headword"].strip().lower()
                    if key in headwords:
                        raise ValueError(f"duplicate vocabulary headword {item['headword']!r} (lesson {lesson_id})")
                    headwords.add(key)

            if lesson["skill"] != "vocabulary":
                if not questions:
                    raise ValueError(f"lesson {lesson_id} has a practice skill but no questions")
                cards = [i for i in lesson["items"] if i["type"] in PRACTICE_CARD_TYPES]
                if len(cards) != 1:
                    raise ValueError(
                        f"lesson {lesson_id} must own exactly one grammarPoint/practiceSet item, found {len(cards)}"
                    )
                if cards[0]["type"] == "grammarPoint" and not cards[0].get("explanationTR", "").strip():
                    raise ValueError(f"lesson {lesson_id} grammar card has an empty explanationTR")
                if cards[0]["type"] == "practiceSet" and "explanationTR" in cards[0]:
                    raise ValueError(f"lesson {lesson_id} practiceSet card must not carry explanationTR")
            elif questions:
                raise ValueError(f"vocabulary lesson {lesson_id} must not carry questions")

            passage_id = lesson.get("passage", {}).get("id")
            # The Swift importer only checks that a question's passageID matches
            # its OWN lesson's passage, so two lessons could ship the same
            # passage id and the app would silently key both to one Passage row.
            # Nothing downstream would catch that, so reject it here.
            if passage_id is not None:
                if passage_id in passage_ids:
                    raise ValueError(f"duplicate passage id {passage_id} (lesson {lesson_id})")
                passage_ids.add(passage_id)
            question_orders = set()
            for question in questions:
                qid = question["id"]
                if qid in question_ids:
                    raise ValueError(f"duplicate question id {qid}")
                question_ids.add(qid)
                if question["kind"] not in QUESTION_KINDS:
                    raise ValueError(f"question {qid} has unknown kind {question['kind']!r}")
                if len(question["options"]) != 5:
                    raise ValueError(f"question {qid} has {len(question['options'])} options, expected 5")
                if not 0 <= question["correctIndex"] <= 4:
                    raise ValueError(f"question {qid} correctIndex {question['correctIndex']} out of range")
                if not question["explanationTR"].strip():
                    raise ValueError(f"question {qid} has an empty explanationTR")
                if any(not option.strip() for option in question["options"]):
                    raise ValueError(f"question {qid} has an empty option")
                if question.get("passageID") is not None and question["passageID"] != passage_id:
                    raise ValueError(f"question {qid} references unknown passage {question['passageID']!r}")
                if question["order"] in question_orders:
                    raise ValueError(f"lesson {lesson_id} has two questions with order {question['order']}")
                question_orders.add(question["order"])
            validate_key_distribution(lesson_id, questions)
            if lesson_id.startswith(GRAMMAR_LESSON_ID_PREFIX):
                validate_grammar_lesson(lesson)
            if lesson_id.startswith(EXAM_LESSON_ID_PREFIX):
                validate_exam_lesson(lesson)
            if lesson_id.startswith(TECH_LESSON_ID_PREFIX):
                validate_tech_lesson(lesson)
            if lesson_id.startswith(VOCAB2_LESSON_ID_PREFIX):
                validate_vocab2_lesson(lesson)


def assemble():
    validate_weights(SKILL_WEIGHTS)
    units = (attach_practice_lessons(load_units()) + load_grammar_units() + load_exam_units()
             + load_tech_units() + load_vocab2_units())
    package = {
        "id": "yds-academic-vocab-1",
        "name": "YDS: Academic Vocabulary I",
        "goal": "yds",
        "storeProductID": "com.niinova22.englishapp.package.yds",
        "levelLower": "B2",
        "levelUpper": "C1",
        "version": PACKAGE_VERSION,
        "skillWeights": SKILL_WEIGHTS,
        "units": [enrich_lessons(u) for u in units],
    }
    validate_content(package)
    return package


def write_output(package, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = json.dumps(package, indent=2, ensure_ascii=False)
    # json.dumps never emits \r, but be explicit and defensive about line
    # endings anyway, and ensure a single trailing newline (matches the
    # existing committed files).
    text = text.replace("\r\n", "\n") + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main():
    package = assemble()
    for path in OUTPUT_PATHS:
        write_output(package, path)
        print(f"Wrote {os.path.relpath(path, REPO_ROOT)}")


if __name__ == "__main__":
    main()
