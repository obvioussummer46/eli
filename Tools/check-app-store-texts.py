#!/usr/bin/env python3
"""Checks the texts in Docs/APP-STORE.md against App Store Connect's
character limits, so nothing gets cut off at paste time.

    python3 Tools/check-app-store-texts.py
"""
import re, sys, os

path = os.path.join(os.path.dirname(__file__), "..", "Docs", "APP-STORE.md")
text = open(path, encoding="utf-8").read()
failures = 0

def check(label, value, limit):
    global failures
    n = len(value)
    ok = n <= limit
    failures += 0 if ok else 1
    print(f"{'ok  ' if ok else 'OVER'} {label:<22} {n:>4}/{limit}")

def field(name):
    m = re.search(r"\*\*" + re.escape(name) + r" \(\d+\):\*\*\s*(.+)", text)
    return m.group(1).strip() if m else ""

def section(title):
    m = re.search(r"^## " + re.escape(title) + r".*?\n\n(.*?)(?=^## )", text, re.S | re.M)
    return m.group(1).strip() if m else ""

check("name", field("Name"), 30)
check("subtitle", field("Subtitle"), 30)
check("promotional text", section("Promotional text (170)"), 170)
check("description", section("Description (4000)"), 4000)
check("keywords", section("Keywords (100)"), 100)
check("what's new", section("What's new (1.0)"), 4000)
for row in re.findall(r"^\| (tip\.\w+|widgets\.pack|icons\.\w+|pro\.\w+) \| (.+?) \| (.+?) \|$", text, re.M):
    check(f"{row[0]} display name", row[1], 30)
    check(f"{row[0]} description", row[2], 45)
sys.exit(1 if failures else 0)
