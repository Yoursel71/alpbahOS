#!/bin/bash
# REBUILD-R2: run scripts/rebuild/<chapter-dir>/NN-*.sh in order, as the current
# non-root user, each in a clean environment:
#     env -i HOME=$HOME TERM=$TERM bash --noprofile --norc <script>
# Usage: run-chapter.sh <chapter-dir> [first-NN]     e.g. run-chapter.sh ch5 07
#
# Per script: log in LOGROOT/<chapter-dir>/NN-<pkg>.log (appended on re-runs),
# with the script's sha256 in the header. Success = rc 0 AND the last line is
# exactly "OK NN-<pkg>". Stops at the first failure. Summary appended to
# LOGROOT/<chapter-dir>/summary.txt.

set -euo pipefail

REBUILD_DIR=$(dirname "$(readlink -f "$0")")
LOGROOT=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs

usage() {
    echo "usage: $0 <chapter-dir> [first-NN]   (chapter-dir: ch5, ch6, ...)" >&2
    exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
chap=$1
first=${2:-01}
[[ $chap =~ ^ch[0-9]+$ ]] || usage
[[ $first =~ ^[0-9]{2}$ ]] || usage

source "$REBUILD_DIR/config.sh"
lfs_guard

CHDIR=$REBUILD_DIR/$chap
if [ ! -d "$CHDIR" ]; then
    echo "no such chapter directory: $CHDIR" >&2
    exit 1
fi

LOGDIR=$LOGROOT/$chap
SUMMARY=$LOGDIR/summary.txt
mkdir -p "$LOGDIR"

shopt -s nullglob
todo=()
for s in "$CHDIR"/[0-9][0-9]-*.sh; do
    nn=$(basename "$s" | cut -c1-2)
    if (( 10#$nn >= 10#$first )); then
        todo+=("$s")
    fi
done
if [ "${#todo[@]}" -eq 0 ]; then
    echo "no scripts with NN >= $first in $CHDIR" >&2
    exit 1
fi

say() { printf '%s\n' "$*" | tee -a "$SUMMARY"; }

RUN_T0=$(date +%s)
say "=== run $(date '+%F %T') chapter=$chap first=$first user=$(id -un) scripts=${#todo[@]}"
echo "chapter $chap: ${#todo[@]} script(s) from $first; logs in $LOGDIR"

for s in "${todo[@]}"; do
    base=$(basename "$s" .sh)
    log=$LOGDIR/$base.log
    expect="OK $base"
    sha=$(sha256sum "$s" | cut -d' ' -f1)

    {
        echo "### $(date '+%F %T') start $base"
        echo "### script: $s"
        echo "### sha256: $sha"
        echo "### runner: env -i HOME=$HOME TERM=${TERM:-dumb} bash --noprofile --norc (user $(id -un), uid $(id -u))"
        echo "### expect last line: $expect"
    } >> "$log"

    echo "start $(date '+%F %T')  $base"
    t0=$(date +%s)
    rc=0
    env -i HOME="$HOME" TERM="${TERM:-dumb}" bash --noprofile --norc "$s" >> "$log" 2>&1 || rc=$?
    t1=$(date +%s)
    dur=$((t1 - t0))
    last=$(tail -n 1 "$log" | tr -d '\r')

    if [ "$rc" -ne 0 ]; then
        status="FAIL(rc=$rc)"
    elif [ "$last" != "$expect" ]; then
        status="FAIL(no final OK line; last='$last')"
    else
        status=OK
    fi

    echo "### $(date '+%F %T') end $base rc=$rc status=$status duration=${dur}s" >> "$log"
    say "$(printf '%-34s rc=%-4s %-8s %6ss  sha256=%s' "$base" "$rc" "$status" "$dur" "$sha")"
    echo "end   $(date '+%F %T')  $base  $status  (${dur}s)"

    if [ "$status" != OK ]; then
        echo "STOPPED at $base. Last 25 log lines:" >&2
        tail -n 25 "$log" >&2
        say "=== STOPPED at $base ($status)"
        exit 1
    fi
done

RUN_T1=$(date +%s)
say "=== ALL OK chapter=$chap scripts=${#todo[@]} total=$((RUN_T1 - RUN_T0))s $(date '+%F %T')"
echo "ALL OK: $chap (${#todo[@]} scripts, $((RUN_T1 - RUN_T0))s)"
