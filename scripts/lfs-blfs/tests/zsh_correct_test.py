import os, pty, select, time, re
R = os.environ.get("ZSH_TEST_ROOT", "/mnt/lfs")   # round 42: any root, e.g. a snapshot of r4-root
ANSI = re.compile(rb'\x1b\[[0-9;?]*[A-Za-z]|\x1b[=>()][A-Za-z0-9]?|\x1b\][^\x07]*\x07')
def read_for(fd, secs):
    buf = b""; end = time.time() + secs
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try: chunk = os.read(fd, 4096)
            except OSError: break
            if not chunk: break
            buf += chunk
    return buf
pid, fd = pty.fork()
if pid == 0:
    env = {"HOME": "/home/alpbah", "TERM": "xterm", "PATH": "/usr/bin:/usr/sbin", "LANG": "C", "USER": "alpbah"}
    os.execve("/usr/sbin/chroot", ["chroot", "--userspec=1000:1000", R, "/bin/zsh", "-i"], env)
read_for(fd, 3)
os.write(fd, b"ehco correct_marker_77\r")
prompt = read_for(fd, 3)
os.write(fd, b"n\r")
after = read_for(fd, 2)
os.write(fd, b"exit\r"); read_for(fd, 2)
try: os.waitpid(pid, 0)
except ChildProcessError: pass
t1 = ANSI.sub(b"", prompt).decode("utf-8", "replace").replace("\r", "")
t2 = ANSI.sub(b"", after).decode("utf-8", "replace").replace("\r", "")
print("--- correction prompt:"); print(t1[-200:])
print("--- after answering n:"); print(t2[-200:])
print("correction_offered:", "correct" in t1.lower() or "ehco" in t1)
print("ran_uncorrected_after_n:", "not found" in t2.lower() or "correct_marker_77" in t2 and "command not found" in t2.lower())
