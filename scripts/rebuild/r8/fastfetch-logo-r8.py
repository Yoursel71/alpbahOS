#!/usr/bin/env python3
"""REBUILD-R8 S2: fastfetch config and ANSI logo for AlpbahOS, written as a staged tree.

The logo follows the brand logo (branding: make-logo.py): a lighter diamond on a dark field. Colours: cyan diamond
(256-colour 51), orange centre (208), navy field (17, background only, so the navy never sits on the terminal
background as text). Output: STAGE/etc/fastfetch/config.jsonc and STAGE/usr/share/fastfetch/alpbahos-logo.txt.
Usage: fastfetch-logo-r8.py <STAGE_DIR>
"""
import os
import sys
STAGE = sys.argv[1]
ESC = "\x1b"
R = 9  # diamond radius in rows; the columns are doubled
rows = []
for y in range(-R - 1, R + 2):
    line = []
    for x in range(-2 * R - 2, 2 * R + 3):
        inside = abs(x) / 2.0 + abs(y) <= R
        if inside and abs(x) <= 1 and y == 0:
            line.append(f"{ESC}[38;5;208;48;5;17m●")
        elif inside:
            line.append(f"{ESC}[38;5;51;48;5;17m█")
        else:
            line.append(f"{ESC}[48;5;17m ")
    rows.append("".join(line) + f"{ESC}[0m")
logo = "\n".join(rows) + "\n"
cfg = r"""{
  "logo": {
    "type": "file",
    "source": "/usr/share/fastfetch/alpbahos-logo.txt",
    "padding": {"right": 3}
  },
  "display": {"separator": "  "},
  "modules": [
    "title",
    "separator",
    {"type": "custom", "format": "\u001b[1;38;5;208mAlpbahOS 0.9 Beta\u001b[0m"},
    "os",
    "kernel",
    "uptime",
    "packages",
    "shell",
    "wm",
    "terminal",
    "cpu",
    "memory",
    "break",
    "colors"
  ]
}
"""
for rel, data in (("etc/fastfetch/config.jsonc", cfg), ("usr/share/fastfetch/alpbahos-logo.txt", logo)):
    p = os.path.join(STAGE, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(data)
    os.chmod(p, 0o644)
print("wrote", STAGE)
