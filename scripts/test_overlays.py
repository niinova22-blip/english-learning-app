#!/usr/bin/env python3
"""Self-test for overlay_lib: the golden overlay merges, and every lint rule
rejects a crafted bad overlay. Run: python3 scripts/test_overlays.py"""
import copy
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from overlay_lib import (OverlayError, apply_overlays, check_cross_package_titles,  # noqa: E402
                         check_titles_domain)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOLDEN = os.path.join(ROOT, "content", "everyday-english-1", "lessons", "day-u01-grammar.json")


def package(audience=None):
    doc = {
        "id": "test-pkg", "goal": "conversational",
        "units": [{"id": "u1", "themeLocalized": {"en": "Daily life", "tr": "Günlük hayat"}, "lessons": [
            {"id": "day-u01-grammar", "skill": "grammar",
             "titleLocalized": {"en": "Grammar", "tr": "Gramer"},
             "items": [{"id": "g1", "type": "grammarPoint", "translationTR": ""}],
             "passage": {"id": "p1", "title": "T", "body": "Text"},
             "questions": [{"id": "q1"}]},
            {"id": "vocab", "skill": "vocabulary",
             "titleLocalized": {"en": "Words", "tr": "Kelimeler"},
             "items": [{"id": "w1", "type": "vocabulary", "translationTR": ""}]},
        ]}],
    }
    if audience:
        doc["audience"] = audience
    return doc


class OverlayTests(unittest.TestCase):
    def setUp(self):
        with open(GOLDEN, encoding="utf-8") as f:
            self.golden = json.load(f)
        self.dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.dir.cleanup()

    def write(self, lesson_id, overlay):
        with open(os.path.join(self.dir.name, lesson_id + ".json"), "w", encoding="utf-8") as f:
            json.dump(overlay, f, ensure_ascii=False)

    def merge(self, overlay, lesson_id="day-u01-grammar", **kw):
        self.write(lesson_id, overlay)
        return apply_overlays(package(), self.dir.name, **kw)

    def rejects(self, overlay, message, **kw):
        with self.assertRaises(OverlayError) as ctx:
            self.merge(overlay, **kw)
        self.assertIn(message, str(ctx.exception))

    def bad_cards(self, mutate):
        overlay = copy.deepcopy(self.golden)
        mutate(overlay["lessonCards"])
        return overlay

    def test_golden_overlay_merges_onto_the_grammar_item(self):
        doc = self.merge(self.golden)
        item = doc["units"][0]["lessons"][0]["items"][0]
        self.assertEqual(item["lessonCards"], self.golden["lessonCards"])

    def test_explanations_passage_and_meanings_merge(self):
        self.write("vocab", {"wordMeanings": {"w1": "kelime"}})
        doc = self.merge({"questionExplanations": {"q1": {"en": "Because.", "tr": "Çünkü."}}, "passageTR": "Metin"})
        grammar, vocab = doc["units"][0]["lessons"]
        self.assertEqual(grammar["questions"][0]["explanationLocalized"], {"en": "Because.", "tr": "Çünkü."})
        self.assertEqual(grammar["passage"]["bodyTR"], "Metin")
        self.assertEqual(vocab["items"][0]["translationTR"], "kelime")

    def test_unknown_ids_are_rejected(self):
        self.rejects(self.golden, "unknown lesson id", lesson_id="nope")
        self.rejects({"questionExplanations": {"q9": {"en": "a", "tr": "b"}}}, "unknown question id")
        self.rejects({"wordMeanings": {"g1": "x"}}, "unknown word item id")
        self.rejects({"extra": 1}, "unknown keys")

    def test_card_rules(self):
        topic = lambda c: c["topics"][0]  # noqa: E731
        cases = [
            (lambda c: c.update(topics=[]), "at least one topic"),
            (lambda c: topic(c).update(pattern=topic(c)["pattern"][:1]), "at least 2 parts"),
            (lambda c: topic(c)["pattern"][0].update(role="noun"), "unknown role"),
            (lambda c: topic(c)["examples"].pop(), "exactly 3 examples"),
            (lambda c: topic(c)["examples"][0].update(en="I " + "really " * 12 + "drink coffee."), "more than 12 words"),
            (lambda c: topic(c)["examples"][0].update(highlight="tea"), "is not in the sentence"),
            (lambda c: topic(c)["examples"][0].update(en="I drink çay."), "Turkish letters"),
            (lambda c: topic(c)["mistake"].update(right="He çalışır."), "Turkish letters"),
            (lambda c: topic(c)["title"].update(tr=" "), "empty text"),
            (lambda c: topic(c)["purpose"].pop("tr"), "exactly 'en' and 'tr'"),
            (lambda c: topic(c)["purpose"].update(en="One. Two. Three."), "more than 2 sentences"),
            (lambda c: c["check"].update(options=["a", "b"]), "exactly 3 options"),
            (lambda c: c["check"].update(correctIndex=3), "correctIndex"),
            (lambda c: c["check"].update(prompt="Ne içersin ----?"), "Turkish letters"),
            (lambda c: c.update(examTip={"en": "Tip", "tr": "İpucu"}), "only for YDS"),
        ]
        for mutate, message in cases:
            with self.subTest(message=message):
                self.rejects(self.bad_cards(mutate), message)

    def test_exam_tip_allowed_for_yds(self):
        overlay = self.bad_cards(lambda c: c.update(examTip={"en": "Tip", "tr": "İpucu"}))
        self.merge(overlay, allow_exam_tip=True)

    def test_cards_need_a_grammar_item(self):
        self.rejects(self.golden, "exactly one grammarPoint", lesson_id="vocab")

    def test_complete_packages_need_every_part(self):
        self.rejects(self.golden, "has no bilingual explanation", require_complete=True)
        with self.assertRaises(OverlayError):
            apply_overlays(package(), self.dir.name, require_complete=True)  # no cards at all
        # A Turkish-medium package only needs the cards.
        self.write("day-u01-grammar", self.golden)
        apply_overlays(package(audience="tr"), self.dir.name, require_complete=True)

    def test_titles_never_name_another_package(self):
        doc = package()
        doc["goal"] = "yds"
        doc["units"][0]["themeLocalized"]["en"] = "Business & Economics"
        with self.assertRaises(OverlayError):
            check_titles_domain(doc)
        doc["goal"] = "business"
        doc["units"][0]["themeLocalized"]["en"] = "YDS words"
        with self.assertRaises(OverlayError):
            check_titles_domain(doc)

    def test_unit_titles_unique_across_packages(self):
        a, b = package(), package()
        b["id"] = "other"
        with self.assertRaises(OverlayError):
            check_cross_package_titles([a, b])
        b["units"][0]["themeLocalized"] = {"en": "Food", "tr": "Yemek"}
        check_cross_package_titles([a, b])


if __name__ == "__main__":
    unittest.main()
