#!/usr/bin/env python3
"""Assemble and lint an English-medium content package (Business English,
Everyday English, ...). The YDS package keeps its own assemble-content.py.

Layout:
  content/<package-id>/package.json      header (see HEADER_KEYS) + "resource"
  content/<package-id>/units/NN-*.json   one unit object per file, sorted by name

Usage:
  assemble-package.py <package-id>            validate + write the app resource
  assemble-package.py <package-id> --check    validate only, fail if the
                                              committed resource differs
  assemble-package.py --unit <file> <package-id>   validate one unit file
  assemble-package.py --all [--check]         every content/*/package.json

Output: App/Sources/EnglishApp/Resources/<resource>.json (UTF-8, LF).
"""
import glob
import json
import os
import re
import sys

from overlay_lib import OverlayError, apply_overlays, check_cross_package_titles, check_titles_domain
from titles_lib import TitlesError, apply_titles

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_DIR = os.path.join(ROOT, "App", "Sources", "EnglishApp", "Resources")
HEADER_KEYS = ["id", "name", "goal", "storeProductID", "levelLower", "levelUpper",
               "version", "audience", "summary", "skillWeights"]
SKILLS = ["vocabulary", "grammar", "reading", "listening", "writing", "speaking", "pronunciation"]
KINDS = {"grammar", "reading", "cloze", "sentenceCompletion", "dialogueCompletion"}
TURKISH = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
ITEM_KEYS = {"id", "type", "headword", "frequencyRank", "baseDifficulty", "definition",
             "exampleSentences", "translationTR", "collocations"}
VOCAB_PER_LESSON = (8, 12)
PRACTICE_QUESTIONS = (5, 10)
MAX_KEY_SHARE = 0.4          # one letter may be the key for at most 40% of a lesson
MAX_LONGEST_SHARE = 0.5      # the key may be the longest option in at most 50% of a unit


class LintError(Exception):
    pass


def fail(where, msg):
    raise LintError(f"{where}: {msg}")


def no_turkish(where, text):
    if TURKISH.search(text or ""):
        fail(where, f"Turkish characters in English-medium content: {text[:60]!r}")


def headword_forms(headword):
    """Lower-case stems a correct example sentence may contain."""
    words = headword.lower().split()
    stem = words[-1]
    forms = {stem}
    for suffix in ("e", "y", "s", "es"):
        if stem.endswith(suffix) and len(stem) > 4:
            forms.add(stem[: -len(suffix)])
    return words[:-1], forms


def check_item(where, item, prefix):
    missing = ITEM_KEYS - set(item)
    if missing:
        fail(where, f"missing keys {sorted(missing)}")
    if not item["id"].startswith(prefix):
        fail(where, f"id {item['id']!r} must start with {prefix!r}")
    if item["translationTR"] != "":
        fail(where, "translationTR must be \"\" in English-medium packages")
    for key in ("headword", "definition"):
        if not item[key].strip():
            fail(where, f"empty {key}")
        no_turkish(where, item[key])
    for s in item["exampleSentences"] + item["collocations"]:
        no_turkish(where, s)
    no_turkish(where, item.get("explanationTR", ""))
    if not 0 <= item["baseDifficulty"] <= 1:
        fail(where, "baseDifficulty outside 0...1")
    if item["type"] == "vocabulary":
        if not 2 <= len(item["exampleSentences"]) <= 3:
            fail(where, "vocabulary needs 2-3 example sentences")
        if not 2 <= len(item["collocations"]) <= 4:
            fail(where, "vocabulary needs 2-4 collocations")
        lead, forms = headword_forms(item["headword"])
        for s in item["exampleSentences"]:
            low = s.lower()
            if not all(w in low for w in lead) or not any(f in low for f in forms):
                fail(where, f"example does not use the headword {item['headword']!r}: {s!r}")
        if item["definition"].lower().startswith(item["headword"].lower() + " "):
            fail(where, "definition must not start with the headword (circular)")


def check_unit(unit, prefix, seen):
    uw = f"unit {unit.get('id')}"
    for key in ("id", "theme", "order", "lessons"):
        if key not in unit:
            fail(uw, f"missing {key}")
    if not unit["id"].startswith(prefix):
        fail(uw, f"id must start with {prefix!r}")
    no_turkish(uw, unit["theme"])
    longest_hits = total_q = 0
    for li, lesson in enumerate(unit["lessons"]):
        lw = f"lesson {lesson.get('id')}"
        for key in ("id", "order", "estimatedDurationMinutes", "title", "skill", "items"):
            if key not in lesson:
                fail(lw, f"missing {key}")
        if not lesson["id"].startswith(prefix):
            fail(lw, f"id must start with {prefix!r}")
        if lesson["order"] != li:
            fail(lw, f"order {lesson['order']} but position {li}")
        if lesson["skill"] not in SKILLS:
            fail(lw, f"bad skill {lesson['skill']}")
        no_turkish(lw, lesson["title"])
        for ident in [lesson["id"]] + [i["id"] for i in lesson["items"]]:
            if ident in seen:
                fail(lw, f"duplicate id {ident}")
            seen.add(ident)
        for item in lesson["items"]:
            check_item(f"{lw} item {item.get('id')}", item, prefix)
        if lesson["skill"] == "vocabulary":
            if any(i["type"] != "vocabulary" for i in lesson["items"]):
                fail(lw, "vocabulary lessons hold vocabulary items only")
            if not VOCAB_PER_LESSON[0] <= len(lesson["items"]) <= VOCAB_PER_LESSON[1]:
                fail(lw, f"{len(lesson['items'])} words; expected {VOCAB_PER_LESSON}")
            if lesson.get("questions"):
                fail(lw, "vocabulary lessons have no questions")
            continue
        cards = [i for i in lesson["items"] if i["type"] in ("grammarPoint", "practiceSet")]
        if len(cards) != 1 or len(lesson["items"]) != 1:
            fail(lw, "practice lessons hold exactly one grammarPoint/practiceSet card")
        if cards[0]["type"] == "grammarPoint" and not cards[0].get("explanationTR", "").strip():
            fail(lw, "grammarPoint card needs explanationTR (the English explanation)")
        questions = lesson.get("questions") or []
        if not PRACTICE_QUESTIONS[0] <= len(questions) <= PRACTICE_QUESTIONS[1]:
            fail(lw, f"{len(questions)} questions; expected {PRACTICE_QUESTIONS}")
        passage = lesson.get("passage")
        if passage:
            no_turkish(lw, passage["title"] + passage["body"])
            if passage["id"] in seen:
                fail(lw, f"duplicate id {passage['id']}")
            seen.add(passage["id"])
        keys = {}
        for qi, q in enumerate(questions):
            qw = f"question {q.get('id')}"
            if q["id"] in seen:
                fail(qw, "duplicate id")
            seen.add(q["id"])
            if not q["id"].startswith(prefix):
                fail(qw, f"id must start with {prefix!r}")
            if q["order"] != qi:
                fail(qw, f"order {q['order']} but position {qi}")
            if q["kind"] not in KINDS:
                fail(qw, f"kind {q['kind']} not in {sorted(KINDS)}")
            if len(q["options"]) != 5 or len(set(o.strip().lower() for o in q["options"])) != 5:
                fail(qw, "exactly 5 distinct options")
            if not 0 <= q["correctIndex"] <= 4:
                fail(qw, "correctIndex out of range")
            if not q["explanationTR"].strip():
                fail(qw, "empty explanation")
            for text in [q["prompt"], q["explanationTR"]] + q["options"]:
                no_turkish(qw, text)
            if q.get("passageID") and (not passage or passage["id"] != q["passageID"]):
                fail(qw, "passageID does not match the lesson passage")
            keys[q["correctIndex"]] = keys.get(q["correctIndex"], 0) + 1
            lengths = [len(o) for o in q["options"]]
            total_q += 1
            if lengths[q["correctIndex"]] == max(lengths) and lengths.count(max(lengths)) == 1:
                longest_hits += 1
        if questions and max(keys.values()) > MAX_KEY_SHARE * len(questions) + 0.001:
            fail(lw, f"answer key too uneven: {keys}")
    if total_q and longest_hits > MAX_LONGEST_SHARE * total_q:
        fail(uw, f"correct option is the longest in {longest_hits}/{total_q} questions (max {MAX_LONGEST_SHARE:.0%})")


def load_header(package_id):
    path = os.path.join(ROOT, "content", package_id, "package.json")
    with open(path, encoding="utf-8") as f:
        header = json.load(f)
    if header["id"] != package_id:
        fail(path, "id does not match the folder name")
    weights = header["skillWeights"]
    if sorted(weights) != sorted(SKILLS) or any(v < 0 for v in weights.values()) or not sum(weights.values()):
        fail(path, "skillWeights must list all 7 skills, non-negative, non-zero total")
    return header


def assemble(package_id):
    header = load_header(package_id)
    prefix = header["idPrefix"]
    files = sorted(glob.glob(os.path.join(ROOT, "content", package_id, "units", "*.json")))
    if not files:
        fail(package_id, "no unit files")
    seen, units, headwords = set(), [], {}
    for order, path in enumerate(files):
        with open(path, encoding="utf-8") as f:
            unit = json.load(f)
        if unit.get("order") != order:
            fail(os.path.basename(path), f"order must be {order}")
        check_unit(unit, prefix, seen)
        for lesson in unit["lessons"]:
            for item in lesson["items"]:
                if item["type"] == "vocabulary":
                    hw = item["headword"].lower()
                    if hw in headwords:
                        fail(item["id"], f"headword {hw!r} already in {headwords[hw]}")
                    headwords[hw] = item["id"]
        units.append(unit)
    doc = {k: header[k] for k in HEADER_KEYS if k in header}
    doc["units"] = units
    try:
        doc = apply_titles(doc, os.path.join(ROOT, "content", package_id, "titles.json"))
    except TitlesError as e:
        fail(package_id, str(e))
    try:
        doc = apply_overlays(doc, os.path.join(ROOT, "content", package_id, "lessons"))
        check_titles_domain(doc)
    except OverlayError as e:
        fail(package_id, str(e))
    return header["resource"], doc


def render(doc):
    return json.dumps(doc, ensure_ascii=False, indent=2) + "\n"


def run(package_id, check):
    resource, doc = assemble(package_id)
    _write(resource, doc, check)
    return doc


def _write(resource, doc, check):
    out = os.path.join(RES_DIR, resource + ".json")
    text = render(doc)
    words = sum(len(l["items"]) for u in doc["units"] for l in u["lessons"] if l["skill"] == "vocabulary")
    qs = sum(len(l.get("questions") or []) for u in doc["units"] for l in u["lessons"])
    print(f"{doc['id']}: {len(doc['units'])} units, {words} words, {qs} questions -> {resource}.json")
    if check:
        current = open(out, encoding="utf-8").read() if os.path.exists(out) else ""
        if current != text:
            sys.exit(f"{out} is stale: run scripts/assemble-package.py {doc['id']}")
    else:
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)


def main(argv):
    try:
        if len(argv) == 4 and argv[1] == "--unit":
            header = load_header(argv[3])
            with open(argv[2], encoding="utf-8") as f:
                check_unit(json.load(f), header["idPrefix"], set())
            print(f"{argv[2]}: OK")
        elif len(argv) >= 2 and argv[1] == "--all":
            docs = [run(os.path.basename(os.path.dirname(p)), "--check" in argv)
                    for p in sorted(glob.glob(os.path.join(ROOT, "content", "*", "package.json")))]
            # The YDS package has its own assembler; compare against its output.
            yds = os.path.join(RES_DIR, "YDSAcademicVocabulary1.json")
            with open(yds, encoding="utf-8") as f:
                docs.append(json.load(f))
            check_cross_package_titles(docs)
        elif len(argv) in (2, 3):
            run(argv[1], len(argv) == 3 and argv[2] == "--check")
        else:
            sys.exit(__doc__)
    except (LintError, OverlayError) as e:
        sys.exit(f"LINT: {e}")


if __name__ == "__main__":
    main(sys.argv)
