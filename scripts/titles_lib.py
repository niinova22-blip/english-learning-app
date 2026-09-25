"""Bilingual interface titles for content packages.

content/<package-id>/titles.json holds the English and Turkish versions of
the package name and summary and of every unit theme and lesson title:
  {"package": {"name": {"en","tr"}, "summary": {"en","tr"}},
   "units": {"<unit id>": {"en","tr"}}, "lessons": {"<lesson id>": {"en","tr"}}}
The app shows the one matching its interface language (learning content stays
in the package's own language). Every id must be covered, in both languages.
"""
import json
import os

LANGS = ("en", "tr")


class TitlesError(Exception):
    pass


def _pair(where, value):
    if not isinstance(value, dict) or set(value) != set(LANGS):
        raise TitlesError(f"{where}: needs exactly 'en' and 'tr'")
    for lang in LANGS:
        if not isinstance(value[lang], str) or not value[lang].strip():
            raise TitlesError(f"{where}: empty '{lang}' title")
    return {lang: value[lang] for lang in LANGS}


def apply_titles(doc, titles_path):
    """Validates titles_path against doc and returns a copy of doc with
    nameLocalized/summaryLocalized/themeLocalized/titleLocalized added."""
    if not os.path.exists(titles_path):
        raise TitlesError(f"{titles_path}: missing")
    with open(titles_path, encoding="utf-8") as f:
        titles = json.load(f)
    units, lessons = titles.get("units", {}), titles.get("lessons", {})
    unit_ids = {u["id"] for u in doc["units"]}
    lesson_ids = {l["id"] for u in doc["units"] for l in u["lessons"]}
    unknown = (set(units) - unit_ids) | (set(lessons) - lesson_ids)
    if unknown:
        raise TitlesError(f"{titles_path}: unknown ids {sorted(unknown)}")

    out = {}
    for key, value in doc.items():
        if key == "units":
            continue
        out[key] = value
        if key == "name":
            out["nameLocalized"] = _pair("package name", titles.get("package", {}).get("name"))
        if key == "summary":
            out["summaryLocalized"] = _pair("package summary", titles.get("package", {}).get("summary"))
    if "summary" not in doc and "summary" in titles.get("package", {}):
        raise TitlesError(f"{titles_path}: summary given but the package has none")
    out["units"] = []
    for unit in doc["units"]:
        if unit["id"] not in units:
            raise TitlesError(f"{titles_path}: unit {unit['id']} has no titles")
        new_unit = dict(unit)
        new_unit["themeLocalized"] = _pair(unit["id"], units[unit["id"]])
        new_lessons = []
        for lesson in unit["lessons"]:
            if lesson["id"] not in lessons:
                raise TitlesError(f"{titles_path}: lesson {lesson['id']} has no titles")
            new_lesson = dict(lesson)
            new_lesson["titleLocalized"] = _pair(lesson["id"], lessons[lesson["id"]])
            new_lessons.append(new_lesson)
        new_unit["lessons"] = new_lessons
        out["units"].append(new_unit)
    return out
