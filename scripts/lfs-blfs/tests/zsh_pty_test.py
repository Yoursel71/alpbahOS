import os, pty, select, time, re, sys
R = os.environ.get("ZSH_TEST_ROOT", "/mnt/lfs")   # round 42: any root, e.g. a snapshot of r4-root
ANSI = re.compile(rb'\x1b\[[0-9;?]*[A-Za-z]|\x1b[=>()][A-Za-z0-9]?|\x1b\][^\x07]*\x07')

def read_for(fd, secs):
    buf = b""
    end = time.time() + secs
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
    return buf

pid, fd = pty.fork()
if pid == 0:
    env = {"HOME": "/home/alpbah", "TERM": "xterm", "PATH": "/usr/bin:/usr/sbin", "LANG": "C", "USER": "alpbah"}
    os.execve("/usr/sbin/chroot", ["chroot", "--userspec=1000:1000", R, "/bin/zsh", "-i"], env)

log = {}
log["boot"] = read_for(fd, 3)
os.write(fd, b"echo suggestme_123\r")
log["first"] = read_for(fd, 2)
os.write(fd, b"echo sugg")
log["typing"] = read_for(fd, 2)
os.write(fd, b"\x1b[C")               # right arrow: accept suggestion into buffer, must NOT run
log["accept"] = read_for(fd, 2)
os.write(fd, b"\x15")                 # Ctrl+U clears the line
read_for(fd, 1)
os.write(fd, b"sleep 60\r")
time.sleep(0.5)
os.write(fd, b"\x03")                 # Ctrl+C must interrupt sleep
log["ctrlc"] = read_for(fd, 3)
os.write(fd, b"exit\r")
read_for(fd, 2)
try:
    os.waitpid(pid, 0)
except ChildProcessError:
    pass

def show(name, data):
    txt = ANSI.sub(b"", data).decode("utf-8", "replace")
    print(f"--- {name} ({len(data)} bytes)")
    print(txt.replace("\r", "")[-400:])

for k in ["boot", "first", "typing", "accept", "ctrlc"]:
    show(k, log[k])
print("suggestion_shown_while_typing:", b"estme_123" in log["typing"] or b"estme_123" in log["accept"])
print("executed_after_accept_without_enter:", log["accept"].count(b"suggestme_123") > 0 and b"\r\nsuggestme_123" in log["accept"])
print("ctrl_c_prompt_returned:", b"root@" in log["ctrlc"] or b"alpbah@" in log["ctrlc"] or b"@alpbahos" in log["ctrlc"])
