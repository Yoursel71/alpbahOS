#!/usr/bin/env python3
"""Round 25: prints "x y" of the top-left corner of the alpbahOS Hoş Geldin window in a screenshot (the largest block of
the window colour #11171c that is about 960x720), or nothing. Usage: find-window.py <png>"""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
px = im.load()
target = (17, 23, 28)
def ok(x, y):
    r, g, b = px[x, y]
    return abs(r - target[0]) <= 2 and abs(g - target[1]) <= 2 and abs(b - target[2]) <= 2
# rows/columns where long runs of the colour exist
for y in range(0, h - 700, 2):
    for x in range(0, w - 940, 2):
        if ok(x, y) and ok(x + 940, y) and ok(x, y + 700) and ok(x + 940, y + 700) and ok(x + 470, y + 3):
            # walk back to the exact corner
            while x > 0 and ok(x - 1, y): x -= 1
            while y > 0 and ok(x, y - 1): y -= 1
            print(x, y)
            sys.exit(0)
