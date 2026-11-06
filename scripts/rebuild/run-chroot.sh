#!/bin/bash
# REBUILD-R2: run a chroot chapter (MLFS 13.1 chapter 7 and later) as root.
# Usage: sudo run-chroot.sh <chapter-dir> [first-NN]     e.g. sudo run-chroot.sh ch7 05
#
# Each script declares where it runs in its second line:
#   # CONTEXT: host    run on the host as root, in a clean environment, LFS=/mnt/lfs13
#   # CONTEXT: chroot  run inside $LFS with chroot(8); the script text is passed to bash -c,
#                      so nothing is copied into the build root
# Mounts: 02-kernfs.sh makes the virtual kernel file systems. This runner unmounts them on
# exit (success, failure, INT, TERM or HUP) and refuses to start if any mount is already
# under $LFS. The unmount never uses -R or -l.
#
# Per script: log in LOGROOT/<chapter-dir>/NN-<pkg>.log (appended on re-runs), with the
# script's sha256 in the header. Success = rc 0 AND the last line is exactly "OK NN-<pkg>".
# Stops at the first failure. Summary appended to LOGROOT/<chapter-dir>/summary.txt.
# Log files are handed back to the build user (yrslf) on exit.

set -euo pipefail

REBUILD_DIR=$(dirname "$(readlink -f "$0")")
LFS=/mnt/lfs13
BUILD_USER=yrslf
LOGROOT=/home/yrslf/alpbahOS/scratch-lfs-bench/lfs13-logs

usage() {
    echo "usage: sudo $0 <chapter-dir> [first-NN]   (chapter-dir: ch7, ...)" >&2
    exit 2
}

[ $# -ge 1 ] && [ $# -le 2 ] || usage
chap=$1
first=${2:-01}
[[ $chap =~ ^ch[0-9]+$ ]] || usage
[[ $first =~ ^[0-9]{2}$ ]] || usage

if [ "$(id -u)" -ne 0 ]; then
    echo "run-chroot.sh: must run as root (sudo)" >&2
    exit 1
fi
if [ ! -d "$LFS/sources" ]; then
    echo "run-chroot.sh: $LFS/sources is missing" >&2
    exit 1
fi
if [ "$(findmnt -T "$LFS" -n -o FSTYPE 2>/dev/null)" != btrfs ]; then
    echo "run-chroot.sh: $LFS is not on btrfs" >&2
    exit 1
fi
mounted=$(findmnt -rn -o TARGET | grep -E "^$LFS(/|\$)" || true)
if [ -n "$mounted" ]; then
    echo "run-chroot.sh: something is already mounted under $LFS; refusing to start:" >&2
    echo "$mounted" >&2
    exit 1
fi

CHDIR=$REBUILD_DIR/$chap
if [ ! -d "$CHDIR" ]; then
    echo "no such chapter directory: $CHDIR" >&2
    exit 1
fi

LOGDIR=$LOGROOT/$chap
SUMMARY=$LOGDIR/summary.txt
mkdir -p "$LOGDIR"

KERNFS_MOUNTS=("$LFS/dev/shm" "$LFS/dev/pts" "$LFS/dev" "$LFS/proc" "$LFS/sys" "$LFS/run")

cleanup() {
    local m
    for m in "${KERNFS_MOUNTS[@]}"; do
        if mountpoint -q "$m"; then
            if ! umount "$m"; then
                echo "WARNING: could not unmount $m; unmount it by hand (umount $m)" >&2
            fi
        fi
    done
    if [ -d "$LOGDIR" ]; then
        chown -R "$BUILD_USER:$BUILD_USER" "$LOGDIR" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

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

# A chroot script needs the kernel file systems (book 7.3). On a resume that starts at a
# chroot script they are not mounted (the previous run unmounted them), so the kernfs
# script is run first, as part of this run.
first_ctx=$(sed -n 's/^# CONTEXT: *//p' "${todo[0]}" | head -n 1)
if [ "$first_ctx" = chroot ] && ! mountpoint -q "$LFS/proc"; then
    if [ ! -f "$CHDIR/02-kernfs.sh" ]; then
        echo "kernfs is not mounted and $CHDIR/02-kernfs.sh does not exist" >&2
        exit 1
    fi
    echo "kernfs not mounted: $CHDIR/02-kernfs.sh runs first"
    todo=("$CHDIR/02-kernfs.sh" "${todo[@]}")
fi

RUN_T0=$(date +%s)
say "=== run $(date '+%F %T') chapter=$chap first=$first user=$(id -un) scripts=${#todo[@]} LFS=$LFS"
echo "chapter $chap: ${#todo[@]} script(s) from $first; logs in $LOGDIR"

for s in "${todo[@]}"; do
    base=$(basename "$s" .sh)
    log=$LOGDIR/$base.log
    expect="OK $base"
    sha=$(sha256sum "$s" | cut -d' ' -f1)
    ctx=$(sed -n 's/^# CONTEXT: *//p' "$s" | head -n 1)

    {
        echo "### $(date '+%F %T') start $base"
        echo "### script: $s"
        echo "### sha256: $sha"
        echo "### context: $ctx"
        echo "### expect last line: $expect"
    } >> "$log"

    echo "start $(date '+%F %T')  $base  [$ctx]"
    t0=$(date +%s)
    rc=0
    case $ctx in
        host)
            env -i HOME=/root TERM="${TERM:-dumb}" LC_ALL=POSIX \
                LFS="$LFS" PATH=/usr/sbin:/usr/bin:/sbin:/bin \
                bash --noprofile --norc "$s" >> "$log" 2>&1 < /dev/null || rc=$?
            ;;
        chroot)
            body=$(cat "$s")
            chroot "$LFS" /usr/bin/env -i \
                HOME=/root \
                TERM="${TERM:-dumb}" \
                PS1='(lfs chroot) \u:\w\$ ' \
                PATH=/usr/bin:/usr/sbin \
                MAKEFLAGS=-j16 \
                TESTSUITEFLAGS=-j16 \
                /bin/bash --noprofile --norc -c "$body" >> "$log" 2>&1 < /dev/null || rc=$?
            ;;
        *)
            echo "### unknown or missing CONTEXT in $s" >> "$log"
            rc=3
            ;;
    esac
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
