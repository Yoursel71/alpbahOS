#!/usr/bin/env python3
"""QMP control of a running QEMU (started by vm-start.sh): keyboard, mouse, screendumps, power.

Usage (QMP socket is <run-dir>/qmp.sock; screen is 1280x800 in the guest):
  qmpctl.py <run-dir> shot <name>                      screendump -> <run-dir>/<name>.ppm (and .png if convert exists)
  qmpctl.py <run-dir> key <key> [<key> ...]            send keys, e.g. ret tab shift-tab backspace a
  qmpctl.py <run-dir> text <string>                    type a string (ASCII letters, digits, a few symbols)
  qmpctl.py <run-dir> click <x> <y>                    left click at pixel x,y (1280x800)
  qmpctl.py <run-dir> powerdown                        ACPI power button
  qmpctl.py <run-dir> quit                             end QEMU
"""
import json
import os
import socket
import subprocess
import sys
import time

W, H = 1280, 800
RUN = sys.argv[1]
CMD = sys.argv[2]
QMP = os.path.join(RUN, "qmp.sock")

CHARS = {" ": "spc", "-": "minus", "=": "equal", ".": "dot", ",": "comma", "/": "slash", "_": "shift-minus",
         "@": "shift-2", ":": "shift-semicolon", "!": "shift-1", "\n": "ret"}


def qmp_session():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(QMP)
    s.settimeout(10)
    s.recv(65536)
    s.sendall(b'{"execute":"qmp_capabilities"}\n')
    s.recv(65536)
    return s


def call(cmd):
    s = qmp_session()
    s.sendall((json.dumps(cmd) + "\n").encode())
    data = s.recv(65536).decode("utf-8", "replace")
    s.close()
    return data


def keys(names):
    for k in names:
        call({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": k}]}})
        time.sleep(0.25)


def char_key(c):
    if c.isalpha() and c.islower() or c.isdigit():
        return [c]
    if c.isupper():
        return ["shift", c.lower()]
    name = CHARS.get(c)
    if name is None:
        raise SystemExit(f"unsupported character {c!r}")
    return name.split("-") if name.startswith("shift") else [name]


def type_text(text):
    for c in text:
        ks = char_key(c)
        call({"execute": "send-key", "arguments": {"keys": [{"type": "qcode", "data": k} for k in ks]}})
        time.sleep(0.12)


def click(x, y):
    ax, ay = int(x * 32767 / (W - 1)), int(y * 32767 / (H - 1))
    call({"execute": "input-send-event", "arguments": {"events": [
        {"type": "abs", "data": {"axis": "x", "value": ax}},
        {"type": "abs", "data": {"axis": "y", "value": ay}}]}})
    time.sleep(0.3)
    call({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": True, "button": "left"}}]}})
    time.sleep(0.1)
    call({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": False, "button": "left"}}]}})


def shot(name):
    ppm = os.path.join(RUN, name + ".ppm")
    call({"execute": "screendump", "arguments": {"filename": ppm}})
    time.sleep(1)
    png = os.path.join(RUN, name + ".png")
    subprocess.run(["convert", ppm, png], stderr=subprocess.DEVNULL)
    print(ppm)


if CMD == "shot":
    shot(sys.argv[3])
elif CMD == "key":
    keys(sys.argv[3:])
elif CMD == "text":
    type_text(sys.argv[3])
elif CMD == "click":
    click(int(sys.argv[3]), int(sys.argv[4]))
elif CMD == "powerdown":
    call({"execute": "system_powerdown"})
elif CMD == "quit":
    call({"execute": "quit"})
else:
    raise SystemExit(f"unknown command {CMD}")
