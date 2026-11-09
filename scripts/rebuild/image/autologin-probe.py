#!/usr/bin/env python3
"""AlpbahOS autologin probe: boot an ISO (or raw image) in QEMU and decide the sddm autologin from the serial log.

The serial console goes to a file (no reader needed, so no backpressure). The DEBUG ISO forwards the journal to the
serial console. Decision:
  success  = the autologin helper started and kwin_wayland logged in the user session (or the session log line)
  fail     = "Auth: sddm-helper exited with" appeared while the helper was the autologin helper (--autologin)
  timeout  = neither within the limit
Usage: autologin-probe.py <uefi|bios> <iso-or-img> <run-dir> [limit-seconds]
Prints one line: RESULT <result> <seconds> <run-dir>
"""
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import json

FW, IMG, RUN = sys.argv[1], sys.argv[2], sys.argv[3]
LIMIT = int(sys.argv[4]) if len(sys.argv) > 4 else 150
OVMF = "/usr/share/edk2/ovmf"
os.makedirs(RUN, exist_ok=True)
SER = os.path.join(RUN, "serial.log")
QMP = os.path.join(RUN, "qmp.sock")
if os.path.exists(SER):
    os.remove(SER)
args = ["-cpu", "qemu64", "-m", os.environ.get("MEM", "6G"), "-smp", "4", "-no-reboot", "-display", "none",
        "-vga", "virtio", "-device", "qemu-xhci", "-device", "usb-kbd", "-device", "usb-tablet",
        "-nic", "user,model=virtio-net-pci", "-serial", f"file:{SER}", "-qmp", f"unix:{QMP},server,nowait"]
if IMG.endswith(".iso"):
    args += ["-drive", f"file={IMG},media=cdrom,readonly=on,if=ide,index=2"]
else:
    args += ["-drive", f"file={IMG},format=raw,if=virtio"]
if FW == "uefi":
    shutil.copy(os.path.join(OVMF, "OVMF_VARS.fd"), os.path.join(RUN, "OVMF_VARS.fd"))
    args = ["-machine", "q35", "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}/OVMF_CODE.fd",
            "-drive", f"if=pflash,format=raw,file={os.path.join(RUN, 'OVMF_VARS.fd')}"] + args
else:
    args = ["-machine", "pc"] + args
qemu = subprocess.Popen(["nice", "-n", "19", "ionice", "-c3", "qemu-system-x86_64"] + args,
                        stdout=subprocess.DEVNULL, stderr=open(os.path.join(RUN, "qemu.err"), "w"))


def qmp(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(QMP)
        s.settimeout(5)
        s.recv(65536)
        s.sendall(b'{"execute":"qmp_capabilities"}\n')
        s.recv(65536)
        s.sendall((json.dumps(cmd) + "\n").encode())
        s.recv(65536)
        s.close()
    except OSError:
        pass


def text():
    try:
        d = open(SER, "rb").read().decode("utf-8", "replace")
    except OSError:
        return ""
    return re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", d).replace("\r", "")


start = time.time()
result = "timeout"
at = 0
while time.time() - start < LIMIT:
    time.sleep(3)
    t = text()
    if "Auth: sddm-helper exited with" in t and "--autologin" in t:
        result = "fail"
        at = int(time.time() - start)
        break
    if re.search(r"kwin_wayland\[\d+\]: .*(No backend|drm)", t) or "Session started true" in t:
        result = "success"
        at = int(time.time() - start)
        break
    if qemu.poll() is not None:
        break
qmp({"execute": "quit"})
try:
    qemu.wait(timeout=30)
except subprocess.TimeoutExpired:
    qemu.kill()
with open(os.path.join(RUN, "result.txt"), "w") as f:
    f.write(f"{result} {at}\n")
print("RESULT", result, at, RUN)
