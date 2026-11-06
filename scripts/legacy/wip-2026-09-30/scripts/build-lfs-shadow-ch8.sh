#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly LIBXCRYPT_LOG="$DATA/logs/lfs-12.4-systemd/libxcrypt-ch8-20260926T214634818668928Z.log"
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/shadow-4.18.0-ch8-$STAMP"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/shadow-ch8-$STAMP.log}"
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    readonly ACCOUNT_BACKUP="$(dirname -- "$ALPBAHOS_D34_LOG_PATH")/shadow-account-files-before-$STAMP"
else
    readonly ACCOUNT_BACKUP="$LOG_DIR/shadow-account-files-before-$STAMP"
fi

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
[[ -r "$LFS/sources/shadow-4.18.0.tar.xz" && -r "$LFS/sources/md5sums" ]] || fail 'Shadow source or official LFS source manifest is missing.'
if [[ -n "${ALPBAHOS_D34_LOCK_FD:-}" ]]; then
    : "${ALPBAHOS_D34_LIBXCRYPT_RUN_DIR:?D34 Libxcrypt evidence directory is required}"
    python3 - "$ALPBAHOS_D34_LIBXCRYPT_RUN_DIR" <<'PY'
import json
import sys
from pathlib import Path

root = Path('/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs')
run = Path(sys.argv[1]).resolve(strict=True)
if root not in run.parents:
    raise SystemExit('Libxcrypt evidence path is outside the D34 replay store')
status = json.loads((run / 'status.json').read_text())
if status.get('package') != 'libxcrypt' or status.get('result') != 'PASS' or status.get('builder_exit_code') != 0:
    raise SystemExit('Libxcrypt D34 status is not PASS')
log = (run / 'package.log').read_text(errors='replace')
for marker in ('# PASS:  32', '# FAIL:  0', 'LIBXCRYPT_CHECK_RESULT=PASS', 'Status: PASS'):
    if marker not in log:
        raise SystemExit(f'Libxcrypt D34 check/install evidence lacks {marker}')
print('Verified D34 Libxcrypt 32-pass check and install.')
PY
else
    rg -q '^LIBXCRYPT_CHECK_RESULT=PASS$' "$LIBXCRYPT_LOG" || fail 'The Libxcrypt check/install did not complete.'
fi
for path in "$LFS/usr/lib/libcrypt.so" "$LFS/usr/include/crypt.h"; do
    [[ -e "$path" || -L "$path" ]] || fail "Required Libxcrypt dependency is missing: $path"
done
for path in "$LFS/usr/bin/passwd" "$LFS/usr/bin/login" "$LFS/usr/bin/useradd" "$LFS/usr/bin/usermod" "$LFS/usr/sbin/passwd" "$LFS/etc/shadow" "$LFS/etc/gshadow" "$LFS/etc/login.defs" "$LFS/etc/default/useradd"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Shadow is already installed/configured: $path"
done
[[ -s "$LFS/etc/passwd" && -s "$LFS/etc/group" ]] || fail 'The current account files are missing.'
awk -F: '$3 == 999 && $1 == "users" { found=1 } END { exit found ? 0 : 1 }' "$LFS/etc/group" || fail 'The LFS users group with GID 999 is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Shadow work: $WORK_ROOT"
[[ ! -e "$ACCOUNT_BACKUP" ]] || fail "Refusing to overwrite account backup: $ACCOUNT_BACKUP"
if ps -eo comm= | awk '$1 == "make" || $1 == "runtest" || $1 == "dejagnu" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'Another make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$ACCOUNT_BACKUP"
cp -p "$LFS/etc/passwd" "$ACCOUNT_BACKUP/passwd"
cp -p "$LFS/etc/group" "$ACCOUNT_BACKUP/group"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building and configuring LFS Chapter 8 Shadow 4.18.0.\n'
printf 'LFS root: %s\nWork root: %s\nAccount file copy: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$ACCOUNT_BACKUP" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected < <(awk '\''$2 == "shadow-4.18.0.tar.xz" { print }'\'' /sources/md5sums)
        test "${#expected[@]}" -eq 1
        printf "%s\\n" "${expected[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/shadow-4.18.0.tar.xz -C "$work_root"
        cd "$work_root/shadow-4.18.0"
        sed -i '\''s/groups$(EXEEXT) //'\'' src/Makefile.in
        find man -name Makefile.in -exec sed -i '\''s/groups\.1 / /'\'' {} +
        find man -name Makefile.in -exec sed -i '\''s/getspnam\.3 / /'\'' {} +
        find man -name Makefile.in -exec sed -i '\''s/passwd\.5 / /'\'' {} +
        sed -e '\''s:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:'\'' -e '\''s:/var/spool/mail:/var/mail:'\'' -e '\''/PATH=/{s@/sbin:@@;s@/bin:@@}'\'' -i etc/login.defs
        touch /usr/bin/passwd
        ./configure --sysconfdir=/etc --disable-static --with-bcrypt --with-yescrypt --without-libbsd --with-group-name-max-length=32
        make
        make exec_prefix=/usr install
        make -C man install-man

        test -x /usr/bin/passwd
        test -x /usr/bin/login
        test -x /usr/sbin/useradd
        test -x /usr/sbin/usermod
        test -d /usr/include/shadow
        test -s /etc/login.defs
        grep -F "ENCRYPT_METHOD YESCRYPT" /etc/login.defs >/dev/null
        grep -F "/var/mail" /etc/login.defs >/dev/null

        pwconv
        grpconv
        mkdir -p /etc/default
        useradd -D --gid 999
        test -s /etc/shadow
        test -s /etc/gshadow
        test -s /etc/default/useradd
        grep -Fx "GROUP=999" /etc/default/useradd >/dev/null
        grep -Fx "CREATE_MAIL_SPOOL=yes" /etc/default/useradd >/dev/null
        printf "SHADOW_ACCOUNT_SETUP=PASS\\n"
        printf "ROOT_SHADOW_ENTRY="
        awk -F: '\''$1 == "root" { print $2 }'\'' /etc/shadow
    ' shadow-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS (Shadow test suite is not provided by LFS)\nRoot password: not set\nAccount file copies: %s\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$ACCOUNT_BACKUP" "$LOG"
