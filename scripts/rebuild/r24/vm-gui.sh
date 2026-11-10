#!/bin/bash
# Round 24 GUI helper for the WELCOME-01 rows (D3) on an installed disk image. Runs as the build user; sudo is not used.
#   start <bios|uefi> <installed-raw> <run-dir>   reflink copy <run-dir>.raw (kept until "stop"; changes persist across
#                                                 boots of the copy), boot it, greeter screenshot at 95 s
#   boot <bios|uefi> <run-dir> <tag>              boot the existing copy again (second login check)
#   login <run-dir>                               type the test password at the greeter (r22.pw copy of r21.pw)
#   type <run-dir> <text>                         Turkish-Q aware typing (same mapping as r20-lanes.sh tq)
#   stop <run-dir>                                quit QEMU and remove the copy
# Screenshots and clicks: scripts/rebuild/image/qmpctl.py <run-dir> shot|click|key|combo.
set -euo pipefail
W=/home/yrslf/alpbahOS/wt-t2-kisayol/scripts/rebuild/image
B=/home/yrslf/alpbahOS/scratch-lfs-bench
CMD=$1; shift
tq() { local RUN="$1"; shift; local s="$*" i c
  for ((i=0; i<${#s}; i++)); do c=${s:i:1}
    case $c in
      -) python3 $W/qmpctl.py "$RUN" key equal ;;
      i) python3 $W/qmpctl.py "$RUN" key apostrophe ;;
      '*') python3 $W/qmpctl.py "$RUN" key minus ;;
      .) python3 $W/qmpctl.py "$RUN" key slash ;;
      /) python3 $W/qmpctl.py "$RUN" combo shift 7 ;;
      ' ') python3 $W/qmpctl.py "$RUN" key spc ;;
      *) python3 $W/qmpctl.py "$RUN" text "$c" ;;
    esac > /dev/null; sleep 0.15; done; }
case "$CMD" in
start)
    FW=$1; SRC=$2; R=$3
    [ ! -e "$R" ] && [ ! -e "$R.raw" ] || { echo "$R exists" >&2; exit 2; }
    cp --reflink=always "$SRC" "$R.raw"
    ACCEL=kvm bash $W/vm-start.sh "$FW" "" "$R" "$R.raw" virtio 6G > /dev/null
    echo "$FW" > "$R/fw"
    sleep 95; python3 $W/qmpctl.py "$R" shot greeter > /dev/null ;;
boot)
    FW=$1; R=$2; TAG=$3
    mkdir -p "$R/$TAG"
    ACCEL=kvm bash $W/vm-start.sh "$FW" "" "$R/$TAG" "$R.raw" virtio 6G > /dev/null
    sleep 95; python3 $W/qmpctl.py "$R/$TAG" shot greeter > /dev/null ;;
login)
    R=$1; PW=$(cat $B/test-secrets/r21.pw)
    python3 $W/qmpctl.py "$R" click 766 489 > /dev/null; sleep 1; tq "$R" "$PW"; python3 $W/qmpctl.py "$R" key ret > /dev/null ;;
type)
    R=$1; shift; tq "$R" "$*" ;;
stop)
    R=$1
    for q in "$R" "$R"/*/; do [ -S "$q/qmp.sock" ] && python3 $W/qmpctl.py "$q" quit > /dev/null 2>&1 || true; done
    sleep 3; rm -f "$R.raw" ;;
*) echo "usage: see header" >&2; exit 2 ;;
esac
