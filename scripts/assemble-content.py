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

QUESTION_KINDS = {"grammar", "reading", "cloze", "sentenceCompletion", "translation"}
PRACTICE_CARD_TYPES = {"grammarPoint", "practiceSet"}

OUTPUT_PATHS = [
    os.path.join(REPO_ROOT, "App", "Sources", "EnglishApp", "Resources", "YDSAcademicVocabulary1.json"),
    os.path.join(REPO_ROOT, "LearningEngine", "Tests", "LearningEngineTests", "Fixtures", "YDSAcademicVocabulary1.json"),
]

# 4: Slice 7a adds practice lessons (questions, passages, grammar topic
# explanations). Bumping this makes installed apps re-import the package.
PACKAGE_VERSION = 4

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


def validate_content(package):
    """Mirrors ContentImporter's validation so authors get the failure here,
    on Windows, seconds after saving -- not half an hour later in macOS CI.
    Also enforces three things the importer cannot: package-wide unique item
    ids, package-wide unique passage ids, and unique question `order` within
    a lesson."""
    question_ids = set()
    item_ids = set()
    passage_ids = set()
    for unit in package["units"]:
        for lesson in unit["lessons"]:
            lesson_id = lesson["id"]
            questions = lesson.get("questions", [])
            for item in lesson["items"]:
                if item["id"] in item_ids:
                    raise ValueError(f"duplicate item id {item['id']}")
                item_ids.add(item["id"])

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
            orders = set()
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
                if question["order"] in orders:
                    raise ValueError(f"lesson {lesson_id} has two questions with order {question['order']}")
                orders.add(question["order"])


def assemble():
    validate_weights(SKILL_WEIGHTS)
    units = attach_practice_lessons(load_units())
    package = {
        "id": "yds-academic-vocab-1",
        "name": "YDS: Academic Vocabulary I",
        "goal": "yds",
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
