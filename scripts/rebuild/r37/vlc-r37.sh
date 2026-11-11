#!/bin/bash
# Round 37 follow-up: VLC with the Xwayland desktop entry (record vlc-alpbahos-desktop, made after the r37 ISO).
# Pre-test on a disposable copy of the r37 UEFI install: the guest's root shell writes the same Exec change into
# /usr/share/applications/vlc.desktop (the copy only; the image gets it from the record in the next ISO), then
# opens a test video the way a user does (kioclient exec <file>: default application from mimeapps.list).
# Enter accepts VLC's first-run privacy dialog, Space pauses and resumes, Alt+Right jumps forward. Screenshot pairs
# are compared on the host. Runs as the build user; the copy is removed at the end.
set -u
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
cd "$WT"
N=${NAME:-VLC1}
M() { env MROUND=r37 bash scripts/rebuild/r21/matrix-r21.sh "$@"; }
D=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r37/matrix
R=$D/$N
G() { python3 scripts/rebuild/r21/gsh.py "$R" "$@"; }
M mkcopy uefi "$N-disk"
M agent "$N" uefi "$N-disk" virtio 6G
G 10 'pkill -u testuser alpbah-hosgeld; sleep 2; echo "welcome left: $(pgrep -u testuser -c alpbah-hosgeld)"'
G 10 'sed -i "s|^Exec=/usr/bin/vlc --started-from-file %U$|Exec=env QT_QPA_PLATFORM=xcb /usr/bin/vlc --started-from-file %U|" /usr/share/applications/vlc.desktop; grep "^Exec=" /usr/share/applications/vlc.desktop'
G 90 'cd /home/testuser && ffmpeg -loglevel error -f lavfi -i testsrc=duration=120:size=640x360:rate=25 -f lavfi -i sine=frequency=440:duration=120 -c:v mpeg4 -q:v 5 -c:a aac test.mp4 && chown testuser: test.mp4 && echo "media ok"'
G 15 'r21m-as-user --bg kioclient exec /home/testuser/test.mp4; echo started'
sleep 15; M shot "$N" vlc-0-privacy
M key "$N" ret; sleep 3
M shot "$N" vlc-1-play-a; sleep 4; M shot "$N" vlc-1-play-b
M key "$N" spc; sleep 2
M shot "$N" vlc-2-paused-a; sleep 4; M shot "$N" vlc-2-paused-b
M key "$N" spc; sleep 3
M shot "$N" vlc-3-resumed-a; sleep 4; M shot "$N" vlc-3-resumed-b
M combo "$N" alt right; sleep 3; M shot "$N" vlc-4-after-jump
G 10 'echo "vlc: $(pgrep -u testuser -a vlc | head -n 1)"; echo "QT_QPA_PLATFORM of vlc: $(tr "\0" "\n" < /proc/$(pgrep -u testuser -x vlc | head -n 1)/environ | grep QT_QPA_PLATFORM)"'
M quit "$N"
rm -f "$D/$N-disk.raw"
python3 - "$R" <<'EOF'
import sys
from PIL import Image, ImageChops
r = sys.argv[1]
def same(a, b):
    A = Image.open(f"{r}/{a}.png").convert("RGB"); B = Image.open(f"{r}/{b}.png").convert("RGB")
    return ImageChops.difference(A, B).getbbox()
for a, b in (("vlc-1-play-a", "vlc-1-play-b"), ("vlc-2-paused-a", "vlc-2-paused-b"), ("vlc-3-resumed-a", "vlc-3-resumed-b")):
    print(f"{a} vs {b}: difference box {same(a, b)}")
EOF
echo "vlc-r37 done $(date +%T)"
