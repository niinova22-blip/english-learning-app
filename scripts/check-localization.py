#!/usr/bin/env python3
"""Fail CI when a string the compiler extracted has no Turkish translation.

Usage: check-localization.py <derived-data-dir>

The Swift compiler writes one *.stringsdata file (JSON) per source file with
every localizable literal it saw (SwiftUI Text/Button/Label keys and
String(localized:)). Each key must exist in Localizable.xcstrings with a
non-empty "tr" value, otherwise Turkish devices silently show English.
Keys without any letter ("%@", "·", "%lld/%lld") need no translation.
"""
import glob
import json
import os
import re
import sys

CATALOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                       "App", "Sources", "EnglishApp", "Resources", "Localizable.xcstrings")


def extracted_keys(derived):
    files = glob.glob(os.path.join(derived, "**", "*.stringsdata"), recursive=True)
    files = [f for f in files if "/EnglishApp.build/" in f.replace("\\", "/")]
    keys = {}
    for path in files:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for table, entries in data.get("tables", {}).items():
            if table != "Localizable":
                continue
            for e in entries:
                keys.setdefault(e["key"], os.path.basename(path))
    return files, keys


def turkish_of(entry):
    tr = entry.get("localizations", {}).get("tr", {})
    return tr.get("stringUnit", {}).get("value", "")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)["strings"]
    files, keys = extracted_keys(sys.argv[1])
    if not files:
        sys.exit("check-localization: no EnglishApp *.stringsdata found — is SWIFT_EMIT_LOC_STRINGS on?")
    missing = [(k, src) for k, src in sorted(keys.items())
               if re.search(r"[A-Za-z]", re.sub(r"%(lld|ld|d|@|lf|f|%)", "", k))
               and not turkish_of(catalog.get(k, {})).strip()]
    bad_plural = []
    for k, e in catalog.items():
        plural = e.get("localizations", {}).get("en", {}).get("variations", {}).get("plural")
        if plural is not None and not {"one", "other"} <= set(plural):
            bad_plural.append(k)
    print(f"check-localization: {len(files)} stringsdata files, {len(keys)} extracted keys, "
          f"{len(catalog)} catalog entries")
    for k, src in missing:
        print(f"  MISSING tr: {k!r}  (from {src})")
    for k in bad_plural:
        print(f"  BAD plural: {k!r}")
    if missing or bad_plural:
        sys.exit(1)
    print("check-localization: OK")


if __name__ == "__main__":
    main()
