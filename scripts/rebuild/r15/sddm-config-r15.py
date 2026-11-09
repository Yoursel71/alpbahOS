#!/usr/bin/env python3
"""REBUILD-R15 (item 6): the SDDM login greeter uses the alpbahos theme.

Round 14 found that the greeter showed SDDM's fallback layout: the main /etc/sddm.conf has an empty [Theme] Current=
(it wins over the drop-in /etc/sddm.conf.d/alpbahos-theme.conf), and the theme's QML could not import
org.kde.breeze.components because the greeter did not have /usr/lib/qml on its QML import path. This writes the main
config with Current=alpbahos and GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml (the greeter gets this environment).
Usage: sddm-config-r15.py <R4_ROOT> <STAGE_DIR>
"""
import os
import re
import sys

R4, STAGE = sys.argv[1], sys.argv[2]
REL = "etc/sddm.conf"
src = open(os.path.join(R4, REL), encoding="utf-8").read()
out = re.sub(r"(?m)^Current=\s*$", "Current=alpbahos", src, count=1)
out = re.sub(r"(?m)^GreeterEnvironment=\s*$", "GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml", out, count=1)
if "Current=alpbahos" not in out or "QML2_IMPORT_PATH=/usr/lib/qml" not in out:
    raise SystemExit("sddm.conf: expected lines not found")
dst = os.path.join(STAGE, REL)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(out)
print("wrote " + REL)
