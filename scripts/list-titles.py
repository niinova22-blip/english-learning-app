#!/usr/bin/env python3
"""Print every package/unit/lesson id with its base title, as a titles.json
skeleton, so the bilingual titles can be authored.

Usage: list-titles.py <Resource name, e.g. BusinessEnglish1>
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main(resource):
    path = os.path.join(ROOT, "App", "Sources", "EnglishApp", "Resources", resource + ".json")
    with open(path, encoding="utf-8") as f:
        pkg = json.load(f)
    out = {"package": {"name": pkg["name"], "summary": pkg.get("summary")},
           "units": {u["id"]: u["theme"] for u in pkg["units"]},
           "lessons": {l["id"]: l["title"] for u in pkg["units"] for l in u["lessons"]}}
    json.dump(out, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main(sys.argv[1])
