#!/usr/bin/env python3
"""Edit App/Sources/EnglishApp/Resources/Localizable.xcstrings safely.

English is the source language: the key IS the English text (with Apple's
format specifiers: %lld for Int, %@ for String, %lf for Double). Every key
needs a Turkish ("tr") value — the exact text the app showed before L1.

Usage:
  l10n.py add "<English key>" "<Turkish>"                    # plain key
  l10n.py add "%lld days" "%lld gün" --plural "%lld day"     # English one/other
  l10n.py remove "<key>"
  l10n.py get "<key>"
  l10n.py list                                               # key<TAB>tr
Keys are kept sorted so diffs stay small. Re-adding a key overwrites it.
"""
import json
import os
import sys

CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                       "App", "Sources", "EnglishApp", "Resources", "Localizable.xcstrings")


def load():
    with open(CATALOG, encoding="utf-8") as f:
        return json.load(f)


def save(data):
    data["strings"] = dict(sorted(data["strings"].items(), key=lambda kv: kv[0]))
    with open(CATALOG, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, separators=(",", " : "))
        f.write("\n")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def add(key, turkish, plural_one=None):
    if not turkish.strip():
        sys.exit(f"empty Turkish value for {key!r}")
    data = load()
    entry = {"extractionState": "manual", "localizations": {"tr": unit(turkish)}}
    if plural_one is not None:
        entry["localizations"]["en"] = {"variations": {"plural": {
            "one": unit(plural_one), "other": unit(key)}}}
    data["strings"][key] = entry
    save(data)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cmd = argv[1]
    if cmd == "add":
        if len(argv) not in (4, 6) or (len(argv) == 6 and argv[4] != "--plural"):
            sys.exit(__doc__)
        add(argv[2], argv[3], argv[5] if len(argv) == 6 else None)
    elif cmd == "remove":
        data = load()
        data["strings"].pop(argv[2], None)
        save(data)
    elif cmd == "get":
        print(json.dumps(load()["strings"].get(argv[2]), ensure_ascii=False, indent=2))
    elif cmd == "list":
        for k, v in load()["strings"].items():
            tr = v.get("localizations", {}).get("tr", {}).get("stringUnit", {}).get("value", "")
            print(f"{k}\t{tr}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
