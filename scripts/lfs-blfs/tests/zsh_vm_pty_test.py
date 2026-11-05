import os, pty, select, time, re
ANSI = re.compile(rb'\x1b\[[0-9;?]*[A-Za-z]|\x1b[=>()][A-Za-z0-9]?|\x1b\][^\x07]*\x07')
def rd(fd, t):
    b = b""; e = time.time() + t
    while time.time() < e:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try: c = os.read(fd, 4096)
            except OSError: break
            if not c: break
            b += c
    return b
def clean(b): return ANSI.sub(b"", b).decode("utf-8", "replace").replace("\r", "")
pid, fd = pty.fork()
if pid == 0:
    os.execve("/bin/zsh", ["/bin/zsh", "-i"], {"HOME": "/home/alpbah", "TERM": "xterm", "PATH": "/usr/bin:/usr/sbin", "LANG": "C", "USER": "alpbah"})
rd(fd, 3)
os.write(fd, b"echo suggestme_123\r"); rd(fd, 2)
os.write(fd, b"echo sugg"); typing = rd(fd, 2)
os.write(fd, b"\x1b[C"); accept = rd(fd, 2)
os.write(fd, b"\x15"); rd(fd, 1)
os.write(fd, b"sleep 60\r"); time.sleep(0.5)
os.write(fd, b"\x03"); ctrlc = rd(fd, 3)
os.write(fd, b"ehco corr_77\r"); corr = rd(fd, 3)
os.write(fd, b"n\r"); after = rd(fd, 2)
os.write(fd, b"exit\r"); rd(fd, 1)
print("suggestion_visible:", b"estme_123" in typing or b"estme_123" in accept)
print("accept_did_not_run:", clean(accept).count("suggestme_123") == 0)
print("ctrl_c_prompt_back:", b"alpbahos" in ctrlc or b"%" in ctrlc)
print("correction_prompt:", "correct 'ehco' to 'echo'" in clean(corr))
print("rejected_back_to_prompt:", b"alpbahos" in after or b"%" in after)
