"""Per-lesson overlays: beginner lesson cards and Turkish/English extras.

content/<package-id>/lessons/<lesson id>.json (every key optional):
  {"lessonCards": {...},                         -> the lesson's grammarPoint item
   "questionExplanations": {"<question id>": {"en","tr"}}  -> question explanationLocalized
   "passageTR": "...",                           -> passage bodyTR
   "wordMeanings": {"<item id>": "..."}}         -> item translationTR

Card rules (one idea per card, beginner level): every {en,tr} pair filled;
pattern >= 2 parts; exactly 3 examples of <= 12 words whose `highlight` is
part of the sentence; one mistake; one check question with 3 options;
`examTip` only where allowed (YDS). English fields carry no Turkish letters.

Packages in REQUIRE_COMPLETE must cover every grammar lesson with cards and,
when English-medium, every question with both explanations, every passage
with a translation and every word with a Turkish meaning.
"""
import copy
import glob
import json
import os
import re

TURKISH = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
ROLES = {"subject", "verb", "aux", "object", "other"}
MAX_EXAMPLE_WORDS = 12
MAX_PURPOSE_SENTENCES = 2
OVERLAY_KEYS = {"lessonCards", "questionExplanations", "passageTR", "wordMeanings"}
CARD_KEYS = {"topics", "check", "examTip"}
TOPIC_KEYS = {"title", "purpose", "pattern", "patternNote", "examples", "mistake"}

# Each content wave adds its package once every lesson is covered.
REQUIRE_COMPLETE = set()


class OverlayError(Exception):
    pass


def fail(where, msg):
    raise OverlayError(f"{where}: {msg}")


def text(where, value):
    if not isinstance(value, str) or not value.strip():
        fail(where, "empty text")
    return value


def english(where, value):
    text(where, value)
    if TURKISH.search(value):
        fail(where, f"Turkish letters in an English field: {value[:60]!r}")
    return value


def pair(where, value):
    if not isinstance(value, dict) or set(value) != {"en", "tr"}:
        fail(where, "needs exactly 'en' and 'tr'")
    english(f"{where}.en", value["en"])
    text(f"{where}.tr", value["tr"])
    return value


def keys(where, value, allowed, required=()):
    if not isinstance(value, dict):
        fail(where, "must be an object")
    unknown = set(value) - set(allowed)
    if unknown:
        fail(where, f"unknown keys {sorted(unknown)}")
    missing = [k for k in required if k not in value]
    if missing:
        fail(where, f"missing {missing}")


def sentence_count(value):
    return len([s for s in re.split(r"[.!?]+(?:\s|$)", value.strip()) if s.strip()])


def check_cards(where, cards, allow_exam_tip):
    keys(where, cards, CARD_KEYS, ("topics", "check"))
    topics = cards["topics"]
    if not isinstance(topics, list) or not topics:
        fail(where, "needs at least one topic")
    for n, topic in enumerate(topics):
        at = f"{where}.topics[{n}]"
        keys(at, topic, TOPIC_KEYS, ("title", "purpose", "pattern", "examples", "mistake"))
        pair(f"{at}.title", topic["title"])
        pair(f"{at}.purpose", topic["purpose"])
        for lang in ("en", "tr"):
            if sentence_count(topic["purpose"][lang]) > MAX_PURPOSE_SENTENCES:
                fail(f"{at}.purpose.{lang}", f"more than {MAX_PURPOSE_SENTENCES} sentences")
        pattern = topic["pattern"]
        if not isinstance(pattern, list) or len(pattern) < 2:
            fail(f"{at}.pattern", "needs at least 2 parts")
        for part in pattern:
            keys(f"{at}.pattern", part, {"text", "role"}, ("text", "role"))
            text(f"{at}.pattern.text", part["text"])
            if part["role"] not in ROLES:
                fail(f"{at}.pattern", f"unknown role {part['role']!r}")
        if "patternNote" in topic:
            pair(f"{at}.patternNote", topic["patternNote"])
        examples = topic["examples"]
        if not isinstance(examples, list) or len(examples) != 3:
            fail(f"{at}.examples", "needs exactly 3 examples")
        for i, example in enumerate(examples):
            ex = f"{at}.examples[{i}]"
            keys(ex, example, {"en", "tr", "highlight"}, ("en", "tr", "highlight"))
            english(f"{ex}.en", example["en"])
            text(f"{ex}.tr", example["tr"])
            if len(example["en"].split()) > MAX_EXAMPLE_WORDS:
                fail(ex, f"more than {MAX_EXAMPLE_WORDS} words")
            if not text(f"{ex}.highlight", example["highlight"]) in example["en"]:
                fail(ex, f"highlight {example['highlight']!r} is not in the sentence")
        mistake = topic["mistake"]
        keys(f"{at}.mistake", mistake, {"wrong", "right", "note"}, ("wrong", "right", "note"))
        english(f"{at}.mistake.wrong", mistake["wrong"])
        english(f"{at}.mistake.right", mistake["right"])
        pair(f"{at}.mistake.note", mistake["note"])
    check = cards["check"]
    keys(f"{where}.check", check, {"prompt", "options", "correctIndex", "explanation"},
         ("prompt", "options", "correctIndex", "explanation"))
    english(f"{where}.check.prompt", check["prompt"])
    if not isinstance(check["options"], list) or len(check["options"]) != 3:
        fail(f"{where}.check", "needs exactly 3 options")
    for option in check["options"]:
        english(f"{where}.check.options", option)
    if len(set(check["options"])) != 3:
        fail(f"{where}.check", "duplicate options")
    if check["correctIndex"] not in (0, 1, 2):
        fail(f"{where}.check", "correctIndex must be 0-2")
    pair(f"{where}.check.explanation", check["explanation"])
    if "examTip" in cards:
        if not allow_exam_tip:
            fail(where, "examTip is only for YDS")
        pair(f"{where}.examTip", cards["examTip"])


def apply_overlays(doc, lessons_dir, allow_exam_tip=False, require_complete=None):
    """Returns a copy of doc with every overlay in lessons_dir merged in."""
    doc = copy.deepcopy(doc)
    package_id = doc["id"]
    if require_complete is None:
        require_complete = package_id in REQUIRE_COMPLETE
    lessons = {l["id"]: l for u in doc["units"] for l in u["lessons"]}
    for path in sorted(glob.glob(os.path.join(lessons_dir, "*.json"))):
        lesson_id = os.path.splitext(os.path.basename(path))[0]
        where = f"{package_id}/lessons/{lesson_id}"
        if lesson_id not in lessons:
            fail(where, "unknown lesson id")
        lesson = lessons[lesson_id]
        with open(path, encoding="utf-8") as f:
            overlay = json.load(f)
        keys(where, overlay, OVERLAY_KEYS)

        if "lessonCards" in overlay:
            grammar = [i for i in lesson["items"] if i["type"] == "grammarPoint"]
            if len(grammar) != 1:
                fail(where, "lessonCards need exactly one grammarPoint item in the lesson")
            check_cards(f"{where}.lessonCards", overlay["lessonCards"], allow_exam_tip)
            grammar[0]["lessonCards"] = overlay["lessonCards"]

        questions = {q["id"]: q for q in lesson.get("questions") or []}
        for qid, value in (overlay.get("questionExplanations") or {}).items():
            if qid not in questions:
                fail(where, f"unknown question id {qid}")
            questions[qid]["explanationLocalized"] = pair(f"{where}.{qid}", value)

        if "passageTR" in overlay:
            if not lesson.get("passage"):
                fail(where, "passageTR but the lesson has no passage")
            lesson["passage"]["bodyTR"] = text(f"{where}.passageTR", overlay["passageTR"])

        items = {i["id"]: i for i in lesson["items"] if i["type"] == "vocabulary"}
        for item_id, meaning in (overlay.get("wordMeanings") or {}).items():
            if item_id not in items:
                fail(where, f"unknown word item id {item_id}")
            items[item_id]["translationTR"] = text(f"{where}.{item_id}", meaning)

    if require_complete:
        check_complete(doc)
    return doc


def check_complete(doc):
    english_medium = doc.get("audience") != "tr"
    for unit in doc["units"]:
        for lesson in unit["lessons"]:
            where = f"{doc['id']}/{lesson['id']}"
            for item in lesson["items"]:
                if item["type"] == "grammarPoint" and "lessonCards" not in item:
                    fail(where, "grammar lesson without lessonCards")
                if english_medium and item["type"] == "vocabulary" and not item["translationTR"].strip():
                    fail(where, f"{item['id']} has no Turkish meaning")
            if not english_medium:
                continue
            for question in lesson.get("questions") or []:
                if "explanationLocalized" not in question:
                    fail(where, f"{question['id']} has no bilingual explanation")
            if lesson.get("passage") and "bodyTR" not in lesson["passage"]:
                fail(where, "passage without a Turkish translation")


# Package-specific naming: no title may name another package's domain.
FOREIGN_WORDS = {
    "yds": ("Business", "İş İngilizcesi"),
    "business": ("YDS",),
    "conversational": ("YDS",),
}


def check_titles_domain(doc):
    words = FOREIGN_WORDS.get(doc["goal"], ())
    titles = []
    for unit in doc["units"]:
        titles += list((unit.get("themeLocalized") or {}).values())
        for lesson in unit["lessons"]:
            titles += list((lesson.get("titleLocalized") or {}).values())
    for title in titles:
        for word in words:
            if word in title:
                fail(doc["id"], f"title {title!r} names another package ({word!r})")


def check_cross_package_titles(docs):
    """No unit theme is shown with the same wording in two packages."""
    seen = {}
    for doc in docs:
        for unit in doc["units"]:
            for lang, value in (unit.get("themeLocalized") or {}).items():
                key = (lang, value.strip().lower())
                if key in seen and seen[key] != doc["id"]:
                    fail(doc["id"], f"unit title {value!r} also used in {seen[key]}")
                seen[key] = doc["id"]
