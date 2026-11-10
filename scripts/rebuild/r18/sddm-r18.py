#!/usr/bin/env python3
"""REBUILD-R18: the SDDM greeter (alpbahos theme) with the logo moved away from the clock and a Turkish locale.

1. Main.qml logo block: the logo sits at the top LEFT (anchors.left parent.left, leftMargin 40, topMargin 40), so it no
   longer overlaps the clock and date at the top centre (checked on 1280x800 and 1920x1080 frames).
2. /etc/sddm.conf: the greeter environment gets LANG=tr_TR.UTF-8 (Turkish date names, 24-hour clock).
   The R15 line GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml is kept.
Idempotent. Usage: sddm-r18.py <R4_ROOT> <STAGE_DIR>
"""
import os
import re
import sys

R4, STAGE = sys.argv[1], sys.argv[2]

# 1. logo block
REL = "usr/share/sddm/themes/alpbahos/Main.qml"
src = open(os.path.join(R4, REL), encoding="utf-8").read()
i = src.index("id: logo\n")
j = src.index("Behavior on opacity", i)
block = src[i:j]
new_block = block
for old, new in [
    ("anchors.horizontalCenter: parent.horizontalCenter\n", "anchors.left: parent.left\n"),
    ("anchors.topMargin: 40\n", "anchors.topMargin: 40\n            anchors.leftMargin: 40\n"),
]:
    if old in new_block:
        new_block = new_block.replace(old, new, 1)
    elif new.strip() not in new_block:
        raise SystemExit("logo block has neither %r nor %r" % (old, new))
out = src[:i] + new_block + src[j:]
dst = os.path.join(STAGE, REL)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(out)
print("patched " + REL + " (changed: %s)" % (out != src))

# 2. sddm.conf locale
REL2 = "etc/sddm.conf"
conf = open(os.path.join(R4, REL2), encoding="utf-8").read()
conf2 = re.sub(r"(?m)^GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml\s*$",
               "GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml,LANG=tr_TR.UTF-8", conf, count=1)
if "LANG=tr_TR.UTF-8" not in conf2:
    raise SystemExit("sddm.conf: GreeterEnvironment line not found")
dst2 = os.path.join(STAGE, REL2)
os.makedirs(os.path.dirname(dst2), exist_ok=True)
with open(dst2, "w", encoding="utf-8") as f:
    f.write(conf2)
print("wrote " + REL2)
