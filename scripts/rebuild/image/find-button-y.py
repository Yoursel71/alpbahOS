#!/usr/bin/env python3
"""Find the vertical centre of the bottom button row of the installer window in a QMP screenshot (PPM/PNG).

Round 40 (INSTALLER-UI-01) changed the installer's sizes, so the fixed "Kur" click of the lanes (y 709/725) missed the
button and no install started. This reads the screenshot instead: in the column X it returns the centre of the lowest run of
18 to 45 rows that is not window background and has window background directly above and below it (the button: its
fill, label and focus line; at least 10 rows of button fill, so the desktop strip between the window and the panel,
which has the window colour, is not taken). Prints the y, or exits 1.
Usage: find-button-y.py <screenshot> <x>
"""
import sys

from PIL import Image


WINDOW_BG = (17, 23, 28)  # installer page background of the alpbah-dark scheme (the panel has the same colour)
BUTTON_FILL = (22, 35, 45)  # push button background of the same scheme


def close(a, b, tol=6):
    return all(abs(p - q) <= tol for p, q in zip(a, b))


def main() -> int:
    im = Image.open(sys.argv[1]).convert("RGB")
    x = int(sys.argv[2])
    h = im.size[1]
    is_bg = [close(im.getpixel((x, y)), WINDOW_BG) for y in range(h)]
    # Runs of non-background rows with window background directly above and below; the lowest one of 18 to 45 rows in
    # the lower half is the button row (its fill, the label text and the focus line all count as the button).
    y = h - 1
    while y > h // 2:
        if is_bg[y] and not is_bg[y - 1]:
            bottom = y - 1
            top = bottom
            while top > 0 and not is_bg[top - 1]:
                top -= 1
            fill = sum(close(im.getpixel((x, r)), BUTTON_FILL, 3) for r in range(top, bottom + 1))
            if 18 <= bottom - top + 1 <= 45 and top > h // 2 and fill >= 10:
                print((top + bottom) // 2)
                return 0
            y = top
        y -= 1
    return 1


if __name__ == "__main__":
    sys.exit(main())
