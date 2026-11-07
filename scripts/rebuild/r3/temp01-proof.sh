#!/bin/bash
# REBUILD-R3-TEMP-01: read-only proof that nothing in the r3-root base resolves the stale perl files.
# Usage: sudo temp01-proof.sh ROOT LIST OUTDIR PHASE   (PHASE: pre or post)
# Mounts /dev, /proc, /sys under ROOT for the duration of the run and unmounts them (no -R, no -l).
# Writes OUTDIR/perl-PHASE.txt (module resolution, @INC, smoke tests). Adds nothing to the base:
# the helper files are removed from ROOT/var/tmp before exit.
set -u
ROOT=$1; LIST=$2; OUT=$3; PHASE=$4
PL=$(dirname "$0")/temp01-check.pl
mkdir -p "$OUT"
mounted=$(findmnt -rn -o TARGET | grep -E "^$ROOT(/|\$)" || true)
[ -z "$mounted" ] || { echo "something already mounted under $ROOT; refusing" >&2; exit 1; }
cleanup() {
  for m in sys proc dev; do mountpoint -q "$ROOT/$m" && umount "$ROOT/$m"; done
  rm -f "$ROOT/var/tmp/temp01-stale.txt" "$ROOT/var/tmp/temp01-check.pl"
}
trap cleanup EXIT
mount --bind /dev "$ROOT/dev" && mount -t proc proc "$ROOT/proc" && mount --bind /sys "$ROOT/sys" || exit 1
cp "$LIST" "$ROOT/var/tmp/temp01-stale.txt"
cp "$PL" "$ROOT/var/tmp/temp01-check.pl"
chroot "$ROOT" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin \
  /usr/bin/perl /var/tmp/temp01-check.pl /var/tmp/temp01-stale.txt > "$OUT/perl-$PHASE.txt" 2>&1
echo "perl rc=$?" >> "$OUT/perl-$PHASE.txt"
chroot "$ROOT" /usr/bin/env -i HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin sh -c '
  for c in "autoreconf --version" "help2man --version" "openssl version"; do
    if command -v ${c%% *} >/dev/null 2>&1; then $c 2>&1 | head -1; echo "rc=$? $c"; else echo "absent: ${c%% *}"; fi
  done' > "$OUT/tools-$PHASE.txt" 2>&1
echo "done $PHASE"
