#!/bin/bash
# REBUILD-R3 driver, run as root. Resumable: a step with a .done marker is skipped.
#   Stage 1: every ch8-ch11 chroot script runs on scratch-lfs-bench/r3-root (a writable copy of
#            the after-ch7 snapshot). Before and after each step the tree is compared
#            (r3_ledger.py diff); the rows go to scratch-lfs-bench/r3-steps/<step>.tsv.
#            ch08-22 (MPFR) runs its build and install with the test gate deferred
#            (22-mpfr-notest.sh); ch08-31b re-runs MPFR after GCC with the full gate (198/0/0).
#   Stage 2: owners (last writer), manifests (alp adopt-base format), the alp prototype is
#            installed into r3-root as its own step, every manifest is adopted with alp.
#   Stage 3: ownership check, comparison with /mnt/lfs13 (dry run), audit-isa.sh.
# /mnt/lfs13 is only read here. Status lines go to scratch-lfs-bench/r3-status.txt.
set -euo pipefail
HERE=$(dirname "$(readlink -f "$0")")
RB=$(dirname "$HERE")
WT=$(dirname "$(dirname "$RB")")
SB=/home/yrslf/alpbahOS/scratch-lfs-bench
R3ROOT=$SB/r3-root
SNAPS=$SB/r3-snap
STEPS=$SB/r3-steps
LEDGER=$SB/r3-ledger
LOGROOT=$SB/lfs13-logs/r3
FETCH=$SB/lfs13-logs/fetch
STATUS=$SB/r3-status.txt
ALP_PY=$WT/docs/handoffs/claude/alp-prototype/alp.py
SNAPDIR=$SB/lfs13-snapshots
NOTEST22=$HERE/22-mpfr-notest.sh
# Scripts whose own gates count test results (STOP on a missing PASS count). Their test targets
# run; every other chroot script runs with the test targets skipped (R3_SKIP_TESTS=1).
TEST_KEEP="03-glibc 20-binutils 21-gmp 22-mpfr 31-gcc 53-python 73-vim"
mkdir -p "$SNAPS" "$STEPS" "$LEDGER" "$LOGROOT"

say() { echo "$(date '+%F %T') $*" | tee -a "$STATUS"; }
snap_ro() { btrfs subvolume snapshot -r "$1" "$2" > /dev/null; }
del_snap() { btrfs subvolume delete "$1" > /dev/null; }
T0=$(date +%s)

[ -d "$R3ROOT/sources" ] || { echo "r3-root missing" >&2; exit 1; }
[ -f "$NOTEST22" ] || { echo "missing $NOTEST22" >&2; exit 1; }
say "=== REBUILD-R3 driver start (root=$R3ROOT)"

PREV=$SNAPS/cur
[ -d "$PREV" ] && del_snap "$PREV"
snap_ro "$R3ROOT" "$PREV"

# run_step ID CHAPTER NN [BODY]: one chroot step, then its tree diff. BODY, if given, replaces the
# script text (used for the deferred-gate MPFR build). Sets PREV to the post-step snapshot.
run_step() {
    local id=$1 chap=$2 nn=$3 body=${4:-} t rc POST cnt
    local extra=()
    [ -f "$STEPS/$id.done" ] && return 0
    [ -n "$body" ] && extra=(R3_BODY_FILE="$body")
    t=$(date +%s)
    say "start $id $chap/$nn${body:+ (body $(basename "$body"))}"
    set +e
    env R3_ROOT="$R3ROOT" R3_LOGROOT="$LOGROOT" R3_SKIP_TESTS=1 R3_TEST_KEEP="$TEST_KEEP" \
        "${extra[@]}" bash "$RB/run-chroot.sh" "$chap" "$nn" "$nn" > "$LOGROOT/driver-$id.out" 2>&1
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        say "FAILED $id rc=$rc (driver output $LOGROOT/driver-$id.out)"
        exit 1
    fi
    POST=$SNAPS/post-$id
    snap_ro "$R3ROOT" "$POST"
    python3 "$HERE/r3_ledger.py" diff "$PREV" "$POST" > "$STEPS/$id.tsv.tmp"
    mv "$STEPS/$id.tsv.tmp" "$STEPS/$id.tsv"
    del_snap "$PREV"
    PREV=$POST
    cnt=$(cut -f1 "$STEPS/$id.tsv" | sort | uniq -c | awk '{printf "%s%s ", $2, $1}')
    touch "$STEPS/$id.done"
    say "done $id $chap/$nn $(( $(date +%s) - t ))s changes: ${cnt:-none}"
}

for n in 8 9 10 11; do
    for s in "$RB/ch$n"/[0-9][0-9]-*.sh; do
        b=$(basename "$s" .sh)
        nn=${b%%-*}
        id=$(printf 'ch%02d-%s' "$n" "$nn")
        # ch8/00 is a repair step for an existing root ("Not part of the 01-82 order" in its
        # header); 03-glibc.sh contains the same step for fresh builds.
        [ "$id" = ch08-00 ] && continue
        if [ "$id" = ch08-22 ]; then
            say "ch08-22 MPFR: build and install with the test gate deferred; the full gate runs as ch08-31b"
            run_step "$id" "ch$n" "$nn" "$NOTEST22"
        else
            run_step "$id" "ch$n" "$nn"
        fi
        if [ "$id" = ch08-31 ]; then
            say "ch08-31b MPFR re-check after GCC: full test gate (198 PASS, 0 SKIP, 0 FAIL)"
            run_step ch08-31b ch8 22
        fi
    done
done

[ -d "$SNAPDIR/after-r3-2026-11-07" ] || snap_ro "$R3ROOT" "$SNAPDIR/after-r3-2026-11-07"
say "stage 1 complete: after-r3-2026-11-07 snapshot in place"

# Stage 2. The alp prototype is installed as its own step (zz-alp), recorded the same way.
if [ ! -f "$STEPS/zz-alp.done" ]; then
    PRE_ALP=$SNAPS/pre-alp
    snap_ro "$R3ROOT" "$PRE_ALP"
    install -D -m 0755 "$ALP_PY" "$R3ROOT/usr/lib/alp/alp.py"
    printf '%s\n' '#!/bin/sh' 'exec python3 /usr/lib/alp/alp.py "$@"' > "$R3ROOT/usr/bin/alp"
    chmod 0755 "$R3ROOT/usr/bin/alp"
    POST_ALP=$SNAPS/post-alp
    snap_ro "$R3ROOT" "$POST_ALP"
    python3 "$HERE/r3_ledger.py" diff "$PRE_ALP" "$POST_ALP" > "$STEPS/zz-alp.tsv"
    del_snap "$PRE_ALP"
    del_snap "$POST_ALP"
    touch "$STEPS/zz-alp.done"
    say "alp prototype installed into r3-root (step zz-alp)"
fi
del_snap "$PREV"

# Chapter 5-7 leftovers: files in the final root that no chapter 8+ step wrote. They get one
# explicit pseudo package (see r3_ledger.py LEFTOVER_STEP), not a per-package record.
python3 "$HERE/r3_ledger.py" split-leftover "$R3ROOT" "$STEPS" "$SNAPDIR" "$LEDGER/temptools-stale.txt" | tee -a "$STATUS"
python3 "$HERE/r3_ledger.py" owners "$STEPS" "$LEDGER/owners.tsv" "$LEDGER/conflicts.tsv" | tee -a "$STATUS"
rm -rf "$LEDGER/manifests"
python3 "$HERE/r3_ledger.py" manifests --owners "$LEDGER/owners.tsv" --root "$R3ROOT" --rb "$RB" \
    --sources "$R3ROOT/sources" --md5sums "$FETCH/md5sums" --wget "$FETCH/wget-list-systemd" \
    --alp "$ALP_PY" --steps "$STEPS" --out "$LEDGER/manifests" | tee -a "$STATUS"

# alp records are rebuilt from scratch: the manifests are regenerated on every run, so records
# from an earlier run would not match (manifest sha256). Only the alp database is removed.
rm -rf "$R3ROOT/var/lib/alp"
ADOPT_LOG=$LOGROOT/adopt-base.log
: > "$ADOPT_LOG"
adopted=0
failed=0
while IFS=$'\t' read -r name version sha manifest entries msha step; do
    [ "$name" = name ] && continue
    # A refused manifest is recorded and the loop goes on; the ownership check shows what is left.
    if python3 "$ALP_PY" --root "$R3ROOT" adopt-base --manifest "$manifest" --name "$name" \
        --version "$version" --source-sha256 "$sha" --manifest-sha256 "$msha" >> "$ADOPT_LOG" 2>&1; then
        adopted=$((adopted + 1))
    else
        echo "ADOPT-REFUSED $name" >> "$ADOPT_LOG"
        failed=$((failed + 1))
    fi
done < "$LEDGER/manifests/index.tsv"
say "alp adopt-base: $adopted recorded, $failed refused (log $ADOPT_LOG)"

INDEX=$WT/docs/handoffs/claude/alp-prototype/demo/index.json
# ALP-TRUST-01: unsigned demo index. --allow-unsigned (root only; run-r3.sh runs as root) only when this alp.py
# knows it, so the line works with the signed-catalog alp.py and with an older one.
UNSIGNED=""
grep -q -- "--allow-unsigned" "$ALP_PY" && UNSIGNED="--allow-unsigned"
bash "$WT/scripts/rebuild/trust/alp-host.sh" "$ALP_PY" --root "$R3ROOT" $UNSIGNED --index "$INDEX" list > "$LEDGER/alp-list.txt" 2>> "$ADOPT_LOG" || true
say "alp list: $(grep -c 'lfs-base' "$LEDGER/alp-list.txt" || true) lfs-base records"
python3 "$HERE/r3_ledger.py" dbowned "$R3ROOT" "$LEDGER/dbowned.txt" | tee -a "$STATUS"

# Stage 3.
set +e
bash "$HERE/ownership-check.sh" "$R3ROOT" "$LEDGER/dbowned.txt" "$HERE/base-generated.txt" \
    > "$LEDGER/ownership-check.txt" 2>&1
own_rc=$?
set -e
say "ownership check RC=$own_rc: $(head -3 "$LEDGER/ownership-check.txt" | tr '\n' ' ')"

rsync -rlpgoDnc --itemize-changes \
    --exclude=/sources --exclude=/root --exclude=/home --exclude=/var/log --exclude=/var/cache \
    --exclude=/var/tmp --exclude=/tmp --exclude=/proc --exclude=/sys --exclude=/dev --exclude=/run \
    --exclude=/var/lib/alp --exclude=/var/lib/alp/ \
    "$R3ROOT/" /mnt/lfs13/ > "$LEDGER/compare-vs-lfs13.txt" 2>&1 || true
say "compare vs /mnt/lfs13 (dry run): $(grep -c '^>' "$LEDGER/compare-vs-lfs13.txt" || true) entries differ, details in $LEDGER/compare-vs-lfs13.txt"

set +e
BASEDIRS="$R3ROOT/usr $R3ROOT/bin $R3ROOT/sbin $R3ROOT/lib $R3ROOT/lib32 $R3ROOT/lib64 $R3ROOT/boot"
bash "$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" $BASEDIRS > "$LEDGER/audit-isa.txt" 2>&1
audit_rc=$?
bash "$WT/scripts/lfs-blfs/cpu-baseline/audit-isa.sh" --include-ko $BASEDIRS > "$LEDGER/audit-isa-ko.txt" 2>&1
audit_ko_rc=$?
set -e
say "audit-isa RC=$audit_rc; audit-isa --include-ko RC=$audit_ko_rc"
say "=== REBUILD-R3 driver end: total $(( $(date +%s) - T0 ))s; ownership RC=$own_rc"
touch "$LEDGER/DONE"
