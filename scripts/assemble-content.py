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

OUTPUT_PATHS = [
    os.path.join(REPO_ROOT, "App", "Sources", "EnglishApp", "Resources", "YDSAcademicVocabulary1.json"),
    os.path.join(REPO_ROOT, "LearningEngine", "Tests", "LearningEngineTests", "Fixtures", "YDSAcademicVocabulary1.json"),
]

PACKAGE_VERSION = 2

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
    stable key order so the committed JSON diff stays readable."""
    enriched = []
    for lesson in unit["lessons"]:
        skill = lesson.get("skill", "vocabulary")
        if skill not in SKILLS:
            raise ValueError(f"lesson {lesson['id']} has invalid skill {skill!r}")
        title = lesson.get("title", f"{unit['theme']} · {lesson['order'] + 1}")
        enriched.append({
            "id": lesson["id"],
            "order": lesson["order"],
            "estimatedDurationMinutes": lesson["estimatedDurationMinutes"],
            "title": title,
            "skill": skill,
            "items": lesson["items"],
        })
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


def assemble():
    validate_weights(SKILL_WEIGHTS)
    return {
        "id": "yds-academic-vocab-1",
        "name": "YDS: Academic Vocabulary I",
        "goal": "yds",
        "levelLower": "B2",
        "levelUpper": "C1",
        "version": PACKAGE_VERSION,
        "skillWeights": SKILL_WEIGHTS,
        "units": [enrich_lessons(u) for u in load_units()],
    }


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
