#!/usr/bin/env python3
"""REBUILD-R19: the SDDM greeter uses Turkish time and date formats (24-hour clock, Turkish day and month names).

R18 set GreeterEnvironment LANG=tr_TR.UTF-8 and the greeter still showed English: the time and date of the Breeze greeter
follow LC_TIME/LC_ALL, which are not set by LANG alone in the greeter session. Measured on an installed r18 copy: adding
LC_ALL=tr_TR.UTF-8 to GreeterEnvironment gives 22:16 and "9 Kasım 2026 Pazartesi". The installed system keeps its
/etc/locale.conf (Calamares choice); only the greeter is fixed to Turkish. Idempotent.
Usage: sddm-r19.py <R4_ROOT> <STAGE_DIR>
"""
import os
import re
import sys

R4, STAGE = sys.argv[1], sys.argv[2]
REL = "etc/sddm.conf"
conf = open(os.path.join(R4, REL), encoding="utf-8").read()
want = "GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml,LANG=tr_TR.UTF-8,LC_ALL=tr_TR.UTF-8"
out, n = re.subn(r"(?m)^GreeterEnvironment=.*$", want, conf, count=1)
if n != 1:
    raise SystemExit("sddm.conf: GreeterEnvironment line not found")
dst = os.path.join(STAGE, REL)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(out)
print("wrote " + REL + " (changed: %s)" % (out != conf))
