#!/usr/bin/env python3
"""REBUILD-R13/R15 (item 6): the SDDM login theme "alpbahos" shows its logo on the login frame.

Reads the R4 root copy of the theme's Main.qml and writes a patched copy into STAGE. Changes to the logo Image block only:
- the opacity is 1 (it no longer follows loginScreenRoot.uiVisible, which hid the logo while the login panel showed);
- the logo sits at the top centre below the status bar (anchors.top, topMargin 40) with a fixed height of 120 px.
  In round 14 it was anchored above the footer (the power-button row) at a height of 3.5 gridUnit, so it was
  drawn over the buttons, too small, and not visible on the login frame.
The function is idempotent: a file that already has the new layout is written unchanged.
Usage: sddm-logo-r13.py <R4_ROOT> <STAGE_DIR>
"""
import os
import sys

R4, STAGE = sys.argv[1], sys.argv[2]
REL = "usr/share/sddm/themes/alpbahos/Main.qml"
src = open(os.path.join(R4, REL), encoding="utf-8").read()
i = src.index("id: logo\n")
j = src.index("Behavior on opacity", i)
block = src[i:j]
new_block = block
for old, new in [
    ("anchors.bottom: footer.top\n", "anchors.top: parent.top\n"),
    ("anchors.bottomMargin: Kirigami.Units.largeSpacing\n", "anchors.topMargin: 40\n"),
    ("height: Math.round(Kirigami.Units.gridUnit * 3.5)", "height: 120"),
    ("opacity: loginScreenRoot.uiVisible ? 0 : 1", "opacity: 1"),
]:
    if old in new_block:
        new_block = new_block.replace(old, new, 1)
    elif new not in new_block:
        raise SystemExit("logo block has neither %r nor %r" % (old, new))
out = src[:i] + new_block + src[j:]
dst = os.path.join(STAGE, REL)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(out)
print("patched " + REL + " (changed: %s)" % (out != src))
