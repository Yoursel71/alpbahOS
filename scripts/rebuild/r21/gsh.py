#!/usr/bin/env python3
"""Round 21 matrix: runs one command in the root test shell of an instrumented copy (unit r21m-agent, guest ttyS1).

Usage: gsh.py <run-dir> <timeout-seconds> <command>     socket <run-dir>/ser1.sock; prints the output, exits with the
       command's exit status (124 on timeout). Timeout 0: send the command and return at once (for shutdown and reboot).
The command and its output are appended to <run-dir>/gsh.log.
"""
import base64
import os
import socket
import sys
import time

run, timeout, cmd = sys.argv[1], float(sys.argv[2]), sys.argv[3]
nonce = os.urandom(4).hex()
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(os.path.join(run, "ser1.sock"))
b64 = base64.b64encode(cmd.encode()).decode()
log = open(os.path.join(run, "gsh.log"), "a")
log.write(f"### {time.strftime('%F %T')} $ {cmd}\n")
if timeout == 0:
    s.sendall(f"echo {b64} | base64 -d | bash > /dev/null 2>&1 &\n".encode())
    time.sleep(0.5)
    log.write("(sent, not waited for)\n")
    sys.exit(0)
s.sendall(f"echo {b64} | base64 -d | bash 2>&1; echo __E''{nonce}__ $?\n".encode())
s.settimeout(1)
buf = b""
end = time.time() + timeout
mark = f"__E{nonce}__ ".encode()
rc = 124
while time.time() < end:
    try:
        d = s.recv(65536)
    except socket.timeout:
        continue
    if not d:
        break
    buf += d
    i = buf.find(mark)
    if i >= 0 and b"\n" in buf[i:]:
        rc = int(buf[i + len(mark):].split()[0])
        buf = buf[:i]
        break
text = buf.decode("utf-8", "replace").replace("\r", "")
sys.stdout.write(text)
log.write(text + f"(rc={rc})\n")
sys.exit(rc)
