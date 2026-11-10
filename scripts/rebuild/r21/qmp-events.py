#!/usr/bin/env python3
"""Round 21 matrix: logs every QMP event of a guest with the host time until QEMU ends.

Usage: qmp-events.py <run-dir>     socket <run-dir>/qmp-ev.sock (a second -qmp socket, so qmpctl.py keeps the first),
                                   output <run-dir>/qmp-events.log (one line per event; "EOF" when QEMU closes it)
"""
import json
import os
import socket
import sys
import time

run = sys.argv[1]
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
for _ in range(50):
    try:
        s.connect(os.path.join(run, "qmp-ev.sock"))
        break
    except OSError:
        time.sleep(0.2)
f = s.makefile("rw")
out = open(os.path.join(run, "qmp-events.log"), "a", buffering=1)
f.readline()
f.write('{"execute":"qmp_capabilities"}\n')
f.flush()
out.write(f"{time.strftime('%F %T')} {time.time():.3f} listener connected\n")
while True:
    try:
        line = f.readline()
    except OSError:
        line = ""
    if not line:
        out.write(f"{time.strftime('%F %T')} {time.time():.3f} EOF (QEMU closed the socket)\n")
        break
    try:
        d = json.loads(line)
    except ValueError:
        continue
    if "event" in d:
        out.write(f"{time.strftime('%F %T')} {time.time():.3f} {d['event']} {json.dumps(d.get('data', {}))}\n")
