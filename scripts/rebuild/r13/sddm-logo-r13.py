#!/usr/bin/env python3
"""REBUILD-R13 (item 6): the SDDM login theme "alpbahos" shows its logo on the login frame.

Reads the R4 root copy of the theme's Main.qml and writes a patched copy into STAGE. The only change: the opacity of
the logo Image no longer follows loginScreenRoot.uiVisible (in the r7 theme it went to 0 whenever the login panel was
shown, so the logo was never visible on the login frame). The copy is recorded by alp (stage-record-r8.py, REPLACE=1).
Usage: sddm-logo-r13.py <R4_ROOT> <STAGE_DIR>
"""
import os
import sys

R4, STAGE = sys.argv[1], sys.argv[2]
REL = "usr/share/sddm/themes/alpbahos/Main.qml"
OLD = "opacity: loginScreenRoot.uiVisible ? 0 : 1"
src = open(os.path.join(R4, REL), encoding="utf-8").read()
i = src.index("id: logo\n")
head, tail = src[:i], src[i:]
j = tail.index(OLD)
tail = tail[:j] + "opacity: 1" + tail[j + len(OLD):]
dst = os.path.join(STAGE, REL)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(head + tail)
print("patched " + REL)
