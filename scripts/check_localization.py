#!/usr/bin/env python3
"""Checks that every user-facing string is localized (English + Ukrainian).

Reads the strings the compiler extracted during a build (*.stringsdata) and compares them with
Resources/Localizable.xcstrings:
  * every extracted key must exist in the catalog,
  * every catalog entry needs a translated Ukrainian value (all plural forms where it varies),
  * the Ukrainian text must use the same format specifiers as the key,
  * entries that nothing uses any more are reported (warning only).

Usage: scripts/check_localization.py [build-products-dir-or-DerivedData]
Exits 1 on any error. Run `xcodebuild ... build` first so the .stringsdata files exist.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOGS = {
    "Localizable": ROOT / "Resources" / "Localizable.xcstrings",
    "InfoPlist": ROOT / "Resources" / "InfoPlist.xcstrings",
}
LANGUAGE = "uk"
UK_PLURALS = {"one", "few", "many", "other"}
SPECIFIER = re.compile(r"%(?:\d+\$)?(?:l{0,2}|h{0,2})[@dDiuUxXoOfeEgGcCsSp]")
# Keys used through APIs the compiler does not extract (package views taking a literal title).
EXTERNAL_KEYS = {"Open popover", "Join next meeting", "Dismiss alert"}


def find_stringsdata(hint):
    roots = [Path(hint)] if hint else []
    if not roots:
        out = subprocess.run(
            ["xcodebuild", "-project", str(ROOT / "NextCall.xcodeproj"), "-scheme", "NextCall",
             "-showBuildSettings"], capture_output=True, text=True).stdout
        match = re.search(r"^\s*OBJROOT = (.+)$", out, re.M)
        if match:
            roots = [Path(match.group(1))]
    files = []
    for base in roots:
        files += [p for p in base.rglob("*.stringsdata") if "NextCall.build" in str(p) and "Objects-normal" in str(p)]
    return files


def extracted_keys(files):
    keys = {}
    for file in files:
        data = json.loads(file.read_text())
        for table, entries in data.get("tables", {}).items():
            for entry in entries:
                keys.setdefault(table, set()).add(entry["key"])
    return keys


def specifiers(text):
    return sorted(SPECIFIER.findall(text))


def translated_values(localization):
    """Yields (label, unit) for every string unit of a localization, including plural variations."""
    if "stringUnit" in localization:
        yield "value", localization["stringUnit"]
    for kind, forms in localization.get("variations", {}).items():
        for form, sub in forms.items():
            if "stringUnit" in sub:
                yield f"{kind}:{form}", sub["stringUnit"]


def main():
    files = find_stringsdata(sys.argv[1] if len(sys.argv) > 1 else None)
    if not files:
        sys.exit("No .stringsdata files found; build the app first (xcodebuild -scheme NextCall build).")
    used = extracted_keys(files)
    errors, warnings = [], []

    for table, path in CATALOGS.items():
        catalog = json.loads(path.read_text())["strings"]
        used_keys = used.get(table, set())

        if table == "Localizable":
            for key in sorted(used_keys - set(catalog)):
                errors.append(f"{table}: '{key}' is used in code but missing from the catalog")
            for key in sorted(set(catalog) - used_keys - EXTERNAL_KEYS):
                warnings.append(f"{table}: '{key}' is in the catalog but unused")

        for key, entry in sorted(catalog.items()):
            localization = entry.get("localizations", {}).get(LANGUAGE)
            if not localization:
                errors.append(f"{table}: '{key}' has no {LANGUAGE} translation")
                continue
            units = list(translated_values(localization))
            if not units:
                errors.append(f"{table}: '{key}' has an empty {LANGUAGE} localization")
            for label, unit in units:
                if unit.get("state") != "translated" or not unit.get("value", "").strip():
                    errors.append(f"{table}: '{key}' [{label}] is not translated")
                elif table == "Localizable" and specifiers(unit["value"]) != specifiers(key) and not label.startswith("plural:"):
                    errors.append(f"{table}: '{key}' [{label}] uses different format specifiers than the key")
            plural_forms = {label.split(":")[1] for label, _ in units if label.startswith("plural:")}
            if plural_forms and not UK_PLURALS <= plural_forms:
                errors.append(f"{table}: '{key}' is missing Ukrainian plural forms {sorted(UK_PLURALS - plural_forms)}")

    for line in warnings:
        print("warning:", line)
    for line in errors:
        print("error:", line)
    total = sum(len(json.loads(p.read_text())["strings"]) for p in CATALOGS.values())
    print(f"{total} catalog entries checked, {len(errors)} errors, {len(warnings)} warnings")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
