#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/dejagnu-1.6.3-ch8-20260926T210700Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/dejagnu-ch8-20260926T210700Z.log}"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ "$(id -u)" != 0 ]] || fail 'Run this host orchestrator as the regular Fedora user.'
[[ -d "$LFS" && -d "$DATA" ]] || fail 'The LFS target or HDD build data directory is missing.'
if [[ -z "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    [[ -d "$DATA/lfs" ]] || fail 'The HDD-backed LFS build directory is missing.'
fi
lfs_validate_target "$LFS" "$DATA"
[[ -c "$LFS/dev/null" ]] || fail 'The chroot /dev mount is not ready.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/dev/pts")" == devpts ]] || fail 'The chroot devpts mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/proc")" == proc ]] || fail 'The chroot proc mount is missing.'
[[ "$(findmnt -n -o FSTYPE -M "$LFS/sys")" == sysfs ]] || fail 'The chroot sysfs mount is missing.'
[[ -r "$LFS/sources/dejagnu-1.6.3.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'DejaGNU source or official LFS source manifest is missing.'
[[ -x "$LFS/usr/bin/expect" && -x "$LFS/usr/bin/tclsh" ]] || fail 'Expect or Tcl dependency is missing.'
[[ ! -e "$LFS/usr/bin/dejagnu" && ! -e "$LFS/usr/bin/runtest" ]] || fail 'DejaGNU is already installed.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior DejaGNU work: $WORK_ROOT"
if pgrep -af 'make (check|test|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-dejagnu-ch8'; then
    fail 'Another LFS make/check/test/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 DejaGNU 1.6.3.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "dejagnu-1.6.3.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/dejagnu-1.6.3.tar.gz -C "$work_root"
        cd "$work_root/dejagnu-1.6.3"
        mkdir -v build
        cd build
        ../configure --prefix=/usr
        makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
        makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi
        make install
        install -v -dm755 /usr/share/doc/dejagnu-1.6.3
        install -v -m644 doc/dejagnu.html doc/dejagnu.txt /usr/share/doc/dejagnu-1.6.3
        test -x /usr/bin/dejagnu
        test -x /usr/bin/runtest
        test -s /usr/share/doc/dejagnu-1.6.3/dejagnu.html
        test -s /usr/share/doc/dejagnu-1.6.3/dejagnu.txt
        printf "Installed DejaGNU 1.6.3.\\n"
    ' dejagnu-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
