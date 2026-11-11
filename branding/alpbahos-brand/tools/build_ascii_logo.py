#!/usr/bin/env python3
"""build_ascii_logo.py -- the alpbahOS terminal (fastfetch) logo from the user's ASCII drawing (2026-11-11).

Input: branding/alpbahos-brand/terminal/alpbahos-ascii.txt (the drawing as given, common indent removed).
Output: branding/alpbahos-brand/terminal/alpbahos-logo.fastfetch.txt with fastfetch colour markers ($1..$4) and a
preview of the colours used. Colours (the navy of the brand is unreadable on dark terminals, so the mountain uses a
lighter brand blue):
  $1 mountain and hill  "#"          38;2;46;112;184
  $2 snow face          "-" "+"      38;2;0;174;239  (cyan #00aeef)
  $3 prompt ">"         "." and the "+"/"-" around it   38;2;244;248;251
  $4 cursor "_"         the two "-----------" runs under the prompt, with their "+" ends  38;2;245;166;35 (orange)
The prompt and the cursor are found by position: the prompt is every non-"#" character within two columns of the
"." characters, from one row above the first "." row to one row below the last; the cursor is the longest "-" runs in
the last rows of the drawing.
Usage: python3 -B build_ascii_logo.py [--check]
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TERM = HERE.parent / "terminal"
SRC = TERM / "alpbahos-ascii.txt"
OUT = TERM / "alpbahos-logo.fastfetch.txt"
COLOURS = {"1": "38;2;46;112;184", "2": "38;2;0;174;239", "3": "38;2;244;248;251", "4": "38;2;245;166;35"}


def classify(lines: list[str]) -> list[list[str]]:
    rows = [list(l) for l in lines]
    kinds = [[" " if c == " " else "1" for c in r] for r in rows]
    prompt_rows = [i for i, r in enumerate(lines) if "." in r]
    # cursor: "-" runs of length >= 8 in the lowest rows that contain such a run left of the face
    cursor = set()
    for i in range(len(lines) - 6, len(lines)):
        for m in re.finditer(r"\+?-{8,}\+?", lines[i]):
            if prompt_rows and i >= prompt_rows[-1] - 1:
                cursor.update((i, j) for j in range(m.start(), m.end()))
    cursor_left = min((j for _, j in cursor), default=10 ** 6)
    dots = [j for i in prompt_rows for j, c in enumerate(lines[i]) if c == "."]
    pc0, pc1 = (min(dots), max(dots)) if dots else (0, -1)
    for i, r in enumerate(rows):
        for j, c in enumerate(r):
            if c in " #":
                continue
            if (i, j) in cursor:
                kinds[i][j] = "4"
            elif prompt_rows and prompt_rows[0] - 1 <= i <= prompt_rows[-1] + 1 and pc0 - 2 <= j <= pc1 + 2 \
                    and j < cursor_left:
                kinds[i][j] = "3"
            else:
                kinds[i][j] = "2"
    return kinds


def render(lines: list[str]) -> str:
    kinds = classify(lines)
    out = []
    for line, kind in zip(lines, kinds):
        s, cur = [], None
        for c, k in zip(line, kind):
            if c != " " and k != cur:
                s.append("$" + k)
                cur = k
            s.append(c)
        out.append("".join(s))
    return "\n".join(out) + "\n"


def main() -> int:
    lines = SRC.read_text(encoding="utf-8").rstrip("\n").split("\n")
    text = render(lines)
    if "--check" in sys.argv:
        ok = OUT.exists() and OUT.read_text(encoding="utf-8") == text
        print("güncel" if ok else "GÜNCEL DEĞİL")
        return 0 if ok else 1
    OUT.write_text(text, encoding="utf-8")
    print(f"{OUT.relative_to(HERE.parent.parent.parent)}: {len(lines)} rows, colours {COLOURS}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
