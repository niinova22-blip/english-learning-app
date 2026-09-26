#!/usr/bin/env python3
"""Creates or completes lesson overlay skeletons for content authors.

Usage: overlay_scaffold.py <package-id> <unit-id> [<unit-id> ...]

For every lesson of the units, content/<package-id>/lessons/<lesson id>.json
gets (keeping anything already written):
  questionExplanations: {"<id>": {"en": <current explanation>, "tr": ""}}
  passageTR: ""                       (lessons with a passage)
  wordMeanings: {"<item id>": ""}     (vocabulary lessons; existing meaning kept)
Grammar cards ("lessonCards") are written by hand after the golden example.
The empty strings make the lint fail until the author fills them in.
English-medium packages only get explanations/translations/meanings; the
YDS package (Turkish-medium) gets nothing but a file to put cards in.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = {"yds-academic-vocab-1": "YDSAcademicVocabulary1", "business-english-1": "BusinessEnglish1",
       "everyday-english-1": "EverydayEnglish1"}


def main(package_id, unit_ids):
    with open(os.path.join(ROOT, "App", "Sources", "EnglishApp", "Resources", RES[package_id] + ".json"), encoding="utf-8") as f:
        doc = json.load(f)
    english_medium = doc.get("audience") != "tr"
    units = {u["id"]: u for u in doc["units"]}
    out_dir = os.path.join(ROOT, "content", package_id, "lessons")
    os.makedirs(out_dir, exist_ok=True)
    for unit_id in unit_ids:
        for lesson in units[unit_id]["lessons"]:
            path = os.path.join(out_dir, lesson["id"] + ".json")
            overlay = {}
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    overlay = json.load(f)
            if english_medium:
                if lesson.get("questions"):
                    explanations = overlay.setdefault("questionExplanations", {})
                    for q in lesson["questions"]:
                        explanations.setdefault(q["id"], {"en": q["explanationTR"], "tr": ""})
                if lesson.get("passage"):
                    overlay.setdefault("passageTR", "")
                words = [i for i in lesson["items"] if i["type"] == "vocabulary"]
                if words:
                    meanings = overlay.setdefault("wordMeanings", {})
                    for item in words:
                        meanings.setdefault(item["id"], item.get("translationTR") or "")
            if not overlay and not any(i["type"] == "grammarPoint" for i in lesson["items"]):
                continue
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(json.dumps(overlay, ensure_ascii=False, indent=2) + "\n")
            print(os.path.relpath(path, ROOT))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2:])
