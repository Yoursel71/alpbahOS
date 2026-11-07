#!/bin/bash
# REBUILD-R4 driver (run as root). Builds the BLFS packages of scripts/rebuild/r4/packages.tsv in plan
# order inside scratch-lfs-bench/r4-root, a btrfs copy of r3-root. One package at a time:
#   1. source: copied from blfs-plan/blfs-src into r4-root/sources/blfs-src. Its md5 must equal the md5 on
#      the BLFS page (packages.tsv). No upstream sha256 is in the repo, so the sha256 is recorded as TOFU.
#   2. script: the BLFS generator of the test image (blfs-plan/gen_blfs_chroot.py) writes the build script.
#   3. build: chroot run of that script. The BLFS commands run `make install` straight into the root,
#      so there is no DESTDIR (fallback method, see docs/verification/rebuild-r4-2026-11-07.md).
#   4. record: read-only snapshots before and after the build, `r3_ledger.py diff`, manifest of the
#      added or changed files (r4_lib.py manifest).
#   5. alp: `alp adopt-base` on r4-root with that manifest, the package name and the sha256 above.
#   6. ISA audit: audit-isa.sh on the new ELF files of the package (default exit code).
#   7. one line in scratch-lfs-bench/r4-status.txt.
# The batch stops at the first FAILED package and writes r4-ledger/FAILED; a finished batch writes
# r4-ledger/DONE. Packages without a local source are SKIP lines.
# Usage: sudo R4_FIRST=001 R4_LAST=030 nohup setsid bash run-r4.sh > <logdir>/driver.out 2>&1 &
set -u
export LC_ALL=C
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
WT=/home/yrslf/alpbahOS/wt-t2-kisayol
DATE=2026-11-07
R4=$SB/r4-root
R3=$SB/r3-root
PLAN=$WT/scripts/rebuild/r4/packages.tsv
LIB=$WT/scripts/rebuild/r4/r4_lib.py
ALP=$WT/docs/handoffs/claude/alp-prototype/alp.py
R3L=$WT/scripts/rebuild/r3/r3_ledger.py
AUDIT=$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh
BLFS=$SB/blfs-plan
LEDGER=$SB/r4-ledger
SNAPS=$SB/r4-snapshots
STATUS=$SB/r4-status.txt
FIRST=${R4_FIRST:-001}
LAST=${R4_LAST:-030}
JOBS=${R4_JOBS:-8}

mkdir -p "$LEDGER/logs" "$LEDGER/diff" "$LEDGER/manifests" "$LEDGER/adopt" "$LEDGER/audit" "$SNAPS"
rm -f "$LEDGER/DONE" "$LEDGER/FAILED"
say() { echo "$(date '+%F %T') $*" >> "$STATUS"; }

# etc/resolv.conf is a link into /run/systemd/resolve, so that directory is bound too: without it the
# network steps (make-ca -g fetches certdata.txt) cannot resolve names inside the chroot.
kernfs_up() {
  for m in dev dev/pts proc sys run/systemd/resolve; do mkdir -p "$R4/$m"; done
  mount --bind /dev "$R4/dev" && mount --bind /dev/pts "$R4/dev/pts" \
    && mount -t proc proc "$R4/proc" && mount --bind /sys "$R4/sys" \
    && mount --bind /run/systemd/resolve "$R4/run/systemd/resolve"
}

kernfs_down() {
  for m in run/systemd/resolve sys proc dev/pts dev; do
    mountpoint -q "$R4/$m" && umount "$R4/$m"
  done
}

preflight() {
  if [ ! -d "$R4/etc" ]; then
    btrfs subvolume snapshot "$R3" "$R4" > /dev/null || { say "FATAL cannot snapshot r3-root"; exit 1; }
    say "r4-root created as a writable btrfs snapshot of r3-root (TEMP-01 not applied: perl files still in use)"
  fi
  if findmnt -rn -o TARGET | grep -qE "^$R4(/|\$)"; then
    say "FATAL something is mounted under r4-root"; exit 1
  fi
  mkdir -p "$R4/sources/blfs-src"
}

# One package. Returns 0 for OK or SKIP, 1 for FAIL (the batch stops).
build_one() {
  local nn=$1 row nv tb md5 localsrc url name ver src got sha start pre post rc elfs n arc summary man
  # Resume: a package with an OK line in the status file is already built and recorded in r4-root.
  if grep -q " OK $nn " "$STATUS" 2>/dev/null; then return 0; fi
  row=$(python3 "$LIB" row --plan "$PLAN" --nn "$nn") || { say "FAIL $nn no plan row"; return 1; }
  IFS=$'\t' read -r nv tb md5 localsrc _ url <<< "$row"
  if [ "$localsrc" != yes ] || [ -z "$tb" ]; then
    say "SKIP $nn $nv no local source (packages.tsv local_source=$localsrc)"; return 0
  fi
  read -r name ver <<< "$(python3 "$LIB" split "$nv")"
  src="$BLFS/blfs-src/$tb"
  start=$(date +%s)

  got=$(python3 "$LIB" md5 "$src" "$md5") || { say "FAIL $nn $nv source md5 $got, BLFS page $md5"; return 1; }
  sha=$(sha256sum "$src" | cut -d' ' -f1)
  cp --reflink=auto "$src" "$R4/sources/blfs-src/$tb"

  runuser -u yrslf -- python3 "$BLFS/gen_blfs_chroot.py" "$nn" > /dev/null 2>&1 \
    || { say "FAIL $nn $nv generator"; return 1; }
  # The export runs after the login profile, which leaves LANG/LC_CTYPE at tr_TR.UTF-8 (the base
  # locale.conf) even when LC_ALL=C is passed to chroot. The script sets C itself.
  { echo 'export LANG=C LC_ALL=C'; cat "$BLFS/gen_blfs/$nn.sh"; } > "$R4/sources/.blfs-$nn.sh" || return 1

  # A build tree left by an earlier failed try keeps its generated files (meson does not regenerate
  # them): start from an empty tree.
  rm -rf "$R4/sources/blfs-build/$nv"
  pre=$SNAPS/pre-$nn-$DATE
  post=$SNAPS/post-$nn-$DATE
  btrfs subvolume snapshot -r "$R4" "$pre" > /dev/null || { say "FAIL $nn $nv snapshot pre"; return 1; }

  kernfs_up || { kernfs_down; say "FAIL $nn $nv kernfs mount"; btrfs subvolume delete "$pre" > /dev/null; return 1; }
  # LC_ALL=C: the base locale (/etc/locale.conf) is tr_TR.UTF-8, where sed's [a-z] range misses 'i'
  # (p11-kit 003 generated "vo_d"). The target keeps its locale; only the build runs in C.
  chroot "$R4" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin MAKEFLAGS=-j"$JOBS" \
    LANG=C LC_ALL=C \
    /bin/bash --login +h "/sources/.blfs-$nn.sh" > "$LEDGER/logs/$nn.log" 2>&1
  rc=$?
  kernfs_down

  btrfs subvolume snapshot -r "$R4" "$post" > /dev/null || { say "FAIL $nn $nv snapshot post"; return 1; }
  if [ $rc -ne 0 ]; then
    say "FAIL $nn $nv build rc=$rc $(( $(date +%s) - start ))s log=$LEDGER/logs/$nn.log"
    btrfs subvolume delete "$pre" "$post" > /dev/null
    return 1
  fi

  "$R3L" diff "$pre" "$post" > "$LEDGER/diff/$nn.tsv"
  man=$LEDGER/manifests/$nn-$name.json
  n=$(python3 "$LIB" manifest --root "$post" --diff "$LEDGER/diff/$nn.tsv" --name "$name" --version "$ver" \
        --url "$url" --sha256 "$sha" --out "$man") \
    || { say "FAIL $nn $nv manifest"; btrfs subvolume delete "$pre" "$post" > /dev/null; return 1; }

  python3 "$ALP" --root "$R4" adopt-base --manifest "$man" --name "$name" --version "$ver" \
    --source-sha256 "$sha" > "$LEDGER/adopt/$nn.log" 2>&1
  if [ $? -ne 0 ]; then
    say "FAIL $nn $nv alp adopt-base refused (log $LEDGER/adopt/$nn.log)"
    btrfs subvolume delete "$pre" "$post" > /dev/null; return 1
  fi

  elfs=$LEDGER/audit/$nn.elfs
  python3 "$LIB" elfs --root "$post" --diff "$LEDGER/diff/$nn.tsv" > "$elfs"
  if [ -s "$elfs" ]; then
    summary=$(xargs -d '\n' -a "$elfs" bash "$AUDIT" 2>&1 | tee "$LEDGER/audit/$nn.txt" | grep '^audit:' | tail -1)
    arc=${PIPESTATUS[0]}
  else
    summary="audit: no ELF files"; arc=0
  fi
  btrfs subvolume delete "$pre" "$post" > /dev/null
  say "OK $nn $nv $(( $(date +%s) - start ))s files=$n sha256=$sha(TOFU) md5=BLFS-page-ok alp=adopted audit_rc=$arc $summary"
  return 0
}

preflight
say "=== R4 batch $FIRST-$LAST start (jobs=$JOBS)"
for nn in $(awk -F'\t' -v a="$FIRST" -v b="$LAST" 'NR>1 && $1>=a && $1<=b {print $1}' "$PLAN"); do
  if ! build_one "$nn"; then
    say "=== R4 batch STOPPED at $nn"
    touch "$LEDGER/FAILED"
    exit 1
  fi
done
say "=== R4 batch $FIRST-$LAST DONE"
touch "$LEDGER/DONE"
