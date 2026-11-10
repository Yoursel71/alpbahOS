#!/usr/bin/env python3
"""Round 24 (PLYMOUTH-01 shutdown row): presses the ACPI power button through QMP, then takes screendumps as fast as one
QMP session allows (PPM files <run-dir>/burst-NNN.ppm with the time since the press in burst.txt) until QEMU closes the
socket or MAX seconds pass. Usage: qmp-burst.py <run-dir> [max-seconds]
"""
import json
import os
import socket
import sys
import time

RUN = sys.argv[1]
MAX = float(sys.argv[2]) if len(sys.argv) > 2 else 60
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(os.path.join(RUN, "qmp.sock"))
s.settimeout(5)
f = s.makefile("rwb")
f.readline()


def cmd(c):
    f.write((json.dumps(c) + "\n").encode())
    f.flush()
    while True:
        line = f.readline()
        if not line:
            raise EOFError
        msg = json.loads(line)
        if "return" in msg or "error" in msg:
            return msg


cmd({"execute": "qmp_capabilities"})
t0 = time.time()
cmd({"execute": "system_powerdown"})
log = open(os.path.join(RUN, "burst.txt"), "w")
n = 0
try:
    while time.time() - t0 < MAX:
        n += 1
        path = os.path.join(RUN, f"burst-{n:03d}.ppm")
        cmd({"execute": "screendump", "arguments": {"filename": path}})
        log.write(f"burst-{n:03d} {time.time() - t0:.2f}\n")
        log.flush()
        time.sleep(0.2)
except (EOFError, OSError, ValueError):
    log.write(f"QEMU closed after {time.time() - t0:.2f} s\n")
print(f"{n} screendumps")
