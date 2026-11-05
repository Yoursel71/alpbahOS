import os, pty, select, time, re
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
pid, fd = pty.fork()
if pid == 0:
    os.execve("/usr/sbin/chroot", ["chroot", "--userspec=1000:1000", "/mnt/lfs", "/bin/zsh", "-i"],
              {"HOME": "/home/alpbah", "TERM": "xterm", "PATH": "/usr/bin:/usr/sbin", "LANG": "C", "USER": "alpbah"})
rd(fd, 3)
os.write(fd, b"_d1(){ print -r -- \"$BUFFER\" > /tmp/alp-a.txt }; zle -N _d1; bindkey '^X1' _d1; _d2(){ print -r -- \"$BUFFER\" > /tmp/alp-b.txt }; zle -N _d2; bindkey '^X2' _d2\r")
rd(fd, 2)
os.write(fd, b"alp inst\t"); rd(fd, 2)
os.write(fd, b"\x181"); rd(fd, 1)
os.write(fd, b"\x15"); rd(fd, 1)
os.write(fd, b"alp install ht\t"); rd(fd, 2)
os.write(fd, b"\x182"); rd(fd, 1)
os.write(fd, b"\x15"); rd(fd, 1)
os.write(fd, b"exit\r"); rd(fd, 1)
try: os.waitpid(pid, 0)
except ChildProcessError: pass
