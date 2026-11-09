#!/usr/bin/env python3
"""AlpbahOS session test: boot an image in QEMU (UEFI or BIOS), log in on the serial console, wait for the
Plasma Wayland session, keep it for N seconds (QMP screendumps), then log the user session out
(`systemctl --user exit`, the same stop path as a logout), and power the guest off.

Serial console: QEMU chardev socket (bidirectional). The test user's password comes from the environment
variable TEST_PASS (a test credential of a test image; never written into this run directory).
Runs as the build user (no root). The disk image is written by QEMU: use a copy of the image.

Usage: TEST_PASS=... session-test.py <bios|uefi> <image.raw> <run-dir> <test-user> <session-seconds>
Writes: <run-dir>/serial.log, guest-*.txt (command output), shot-*.png, summary.txt
"""
import os
import re
import shutil
import socket
import subprocess
import sys
import time

FW, IMG, RUN, USER, SESSION = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5])
PASS = os.environ["TEST_PASS"]
OVMF = "/usr/share/edk2/ovmf"
os.makedirs(RUN, exist_ok=True)
SER_SOCK = os.path.join(RUN, "serial.sock")
QMP_SOCK = os.path.join(RUN, "qmp.sock")
SERIAL_LOG = os.path.join(RUN, "serial.log")
TL = open(os.path.join(RUN, "timeline.txt"), "a", buffering=1)


def tl(msg):
    TL.write(f"{time.strftime('%H:%M:%S')} {msg}\n")


args = ["-cpu", "qemu64", "-m", os.environ.get("MEM", "6G"), "-smp", "4", "-no-reboot", "-display", "none", "-vga", "virtio",
        "-device", "qemu-xhci", "-device", "usb-kbd", "-device", "usb-tablet",
        "-nic", "user,model=virtio-net-pci",
        # An .iso image is the live medium (CD-ROM, IDE); a raw image is the installed disk (virtio).
        *(["-drive", f"file={IMG},media=cdrom,readonly=on,if=ide,index=2"] if IMG.endswith(".iso")
          else ["-drive", f"file={IMG},format=raw,if=virtio"]),
        "-chardev", f"socket,id=ser0,path={SER_SOCK},server=on,wait=off,logfile={SERIAL_LOG}",
        "-serial", "chardev:ser0",
        "-qmp", f"unix:{QMP_SOCK},server,nowait"]
if FW == "uefi":
    shutil.copy(os.path.join(OVMF, "OVMF_VARS.fd"), os.path.join(RUN, "OVMF_VARS.fd"))
    args = ["-machine", "q35",
            "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF}/OVMF_CODE.fd",
            "-drive", f"if=pflash,format=raw,file={os.path.join(RUN, 'OVMF_VARS.fd')}"] + args
else:
    args = ["-machine", "pc"] + args
cmd = ["nice", "-n", "19", "ionice", "-c3", "qemu-system-x86_64"] + args
with open(os.path.join(RUN, "command.txt"), "w") as f:
    f.write(" ".join(cmd) + "\n")
qemu = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=open(os.path.join(RUN, "qemu.err"), "w"))
tl(f"qemu started pid {qemu.pid} fw={FW} img={os.path.basename(IMG)}")


class Serial:
    """Serial console client. A reader thread drains the socket all the time: if nobody reads, QEMU's
    chardev backpressure stalls the guest's console writes (the boots were 30 s per unit in that state)."""

    def __init__(self):
        import threading
        for _ in range(300):
            if os.path.exists(SER_SOCK):
                break
            time.sleep(0.2)
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(SER_SOCK)
        self.s.settimeout(0.5)
        self.buf = ""
        self.lock = threading.Lock()
        self.alive = True
        self.th = threading.Thread(target=self._reader, daemon=True)
        self.th.start()

    def _reader(self):
        while self.alive:
            try:
                data = self.s.recv(65536)
                if not data:
                    break
                with self.lock:
                    self.buf += data.decode("utf-8", "replace")
            except socket.timeout:
                continue
            except OSError:
                break

    def pump(self):
        time.sleep(0.3)
        return self.alive

    def expect(self, pat, timeout):
        end = time.time() + timeout
        while time.time() < end:
            with self.lock:
                m = re.search(pat, self.buf)
                if m:
                    self.last_before = self.buf[:m.start()]
                    self.buf = self.buf[m.end():]
                    return m
            if not self.pump():
                break
        return None

    def send(self, text):
        self.s.sendall(text.encode())

    def run(self, command, timeout=120):
        n = int(time.time() * 1000) % 1000000
        self.buf = ""
        self.send(f'{command}; echo "__D""ONE_{n}__$?"\r')
        m = self.expect(rf"__DONE_{n}__(\d+)", timeout)
        return (m.group(0) if m else "TIMEOUT"), (self.last_before if m else self.buf)


def qmp(cmd):
    import json
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(QMP_SOCK)
        s.settimeout(5)
        s.recv(65536)
        s.sendall(b'{"execute":"qmp_capabilities"}\n')
        s.recv(65536)
        s.sendall((json.dumps(cmd) + "\n").encode())
        s.recv(65536)
        s.close()
    except OSError as e:
        tl(f"qmp error {e}")


def shot(name):
    qmp({"execute": "screendump", "arguments": {"filename": os.path.join(RUN, name)}})


def snap_text(ser, command, name, timeout=60):
    tag, out = ser.run(command, timeout)
    with open(os.path.join(RUN, name), "w") as f:
        f.write(f"$ {command}\n{tag}\n")
        f.write(out + "\n")
    return tag


ser = Serial()
result = {}
if os.environ.get("NOLOGIN"):
    # Release live image: no password for the live user, so no serial login. Screenshots only (QMP).
    try:
        start = time.time()
        shots = 0
        while time.time() - start < SESSION:
            time.sleep(30)
            if int(time.time() - start) // 60 > shots:
                shots = int(time.time() - start) // 60
                shot(f"shot-{shots * 60:04d}s.ppm")
                tl(f"shot at {shots * 60}s")
        shot("shot-end.ppm")
    finally:
        qmp({"execute": "system_powerdown"})
        tl("system_powerdown sent")
        for _ in range(9):
            if qemu.poll() is not None:
                break
            time.sleep(20)
        if qemu.poll() is None:
            qmp({"execute": "quit"})
            tl("quit sent")
        try:
            qemu.wait(timeout=60)
        except subprocess.TimeoutExpired:
            qemu.kill()
        with open(os.path.join(RUN, "summary.txt"), "w") as f:
            f.write(f"qemu_rc={qemu.returncode}\nmode=nologin screenshots only\n")
        print("SESSION_TEST_DONE nologin")
    sys.exit(0)
try:
    if not ser.expect(r"login: ", 900):
        raise RuntimeError("no login prompt")
    tl("login prompt")
    ser.send(USER + "\r")
    # The console is localized (tr_TR): the prompt may read "Parola:" or "Password:".
    if not ser.expect(r"(?i)(password|parola|sifre|şifre)[^\r\n]*:", 60):
        raise RuntimeError("no password prompt")
    ser.send(PASS + "\r")
    if not ser.expect(r"\$ $|\$ \r?\n|# ", 120):
        raise RuntimeError("no shell prompt")
    ser.send("export PS1='GUEST# '\r")
    ser.expect(r"GUEST# ", 30)
    tl("logged in on serial")
    # DIAG_CMDS (optional, ';'-free list separated by '|'): run these commands on the serial shell and keep
    # their output in guest-diag.txt, then end the run (diagnostic runs only).
    if os.environ.get("DIAG_CMDS"):
        out = []
        for c in os.environ["DIAG_CMDS"].split("|"):
            tag, text = ser.run(c, 60)
            out.append(f"$ {c}\n{tag}\n{text}\n")
        with open(os.path.join(RUN, "guest-diag.txt"), "w") as f:
            f.write("".join(out))
        tl("diagnostic commands done")
        raise RuntimeError("diagnostic run: no session test")
    # Wait for the Plasma session of the user (sddm autologin or the greeter login of the same user).
    ok = False
    for _ in range(90):
        tag, out = ser.run("systemctl --user is-active plasma-workspace.target", 30)
        if "TIMEOUT" not in tag and re.search(r"(?<![A-Za-z])active\r?\n", out) and tag.endswith("0"):
            ok = True
            break
        time.sleep(10)
    result["plasma_active"] = ok
    tl(f"plasma-workspace.target active={ok}")
    start = time.time()
    shots = 0
    while time.time() - start < SESSION:
        time.sleep(30)
        if int(time.time() - start) // 60 > shots:
            shots = int(time.time() - start) // 60
            shot(f"shot-{shots * 60:04d}s.ppm")
            tl(f"shot at {shots * 60}s of session")
    shot("shot-end.ppm")
    snap_text(ser, "systemctl --user --failed --no-legend; echo ---; journalctl --user -b --no-pager | grep -i 'dump\\|abort\\|assert\\|SIG\\|Failed with\\|Main process' | tail -60", "guest-before-logout.txt", 120)
    snap_text(ser, "coredumpctl list --no-pager 2>&1 | tail -20", "guest-coredumps-before.txt", 60)
    tl("logout: systemctl --user exit")
    ser.send("systemctl --user exit\r")
    time.sleep(90)
    ser.buf = ""
    ser.pump()
    tl("waited 90 s after user-manager exit")
except Exception as e:  # keep the run directory even if the test failed
    result["error"] = str(e)
    tl(f"ERROR {e}")
finally:
    try:
        shot("shot-final.ppm")
    except Exception:
        pass
    qmp({"execute": "system_powerdown"})
    tl("system_powerdown sent")
    for _ in range(9):
        if qemu.poll() is not None:
            break
        time.sleep(20)
    if qemu.poll() is None:
        qmp({"execute": "quit"})
        tl("quit sent")
    try:
        qemu.wait(timeout=60)
    except subprocess.TimeoutExpired:
        qemu.kill()
    with open(os.path.join(RUN, "summary.txt"), "w") as f:
        f.write(f"qemu_rc={qemu.returncode}\n")
        for k, v in result.items():
            f.write(f"{k}={v}\n")
    print("SESSION_TEST_DONE", result)
