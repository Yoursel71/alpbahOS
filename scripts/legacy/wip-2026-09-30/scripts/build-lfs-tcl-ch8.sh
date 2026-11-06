#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly WORK_ROOT=/sources/tcl-8.6.16-ch8-20260926T210300Z
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/tcl-ch8-20260926T210300Z.log}"

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
[[ -r "$LFS/sources/tcl8.6.16-src.tar.gz" && -r "$LFS/sources/tcl8.6.16-html.tar.gz" && -r "$LFS/sources/md5sums" ]] || fail 'Tcl sources or official LFS source manifest are missing.'
for path in "$LFS/usr/bin/tclsh" "$LFS/usr/bin/tclsh8.6" "$LFS/usr/lib/libtcl8.6.so" "$LFS/usr/include/tcl8.6/tcl.h"; do
    [[ ! -e "$path" && ! -L "$path" ]] || fail "Tcl is already installed: $path"
done
[[ ! -e "$LFS/usr/share/man/man3/Tcl_Thread.3" ]] || fail 'Tcl_Thread.3 already exists; refusing to overwrite it.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite prior Tcl work: $WORK_ROOT"
if pgrep -af 'make (check|test|.*subdir=.*tests|install)' | grep -v '[b]uild-lfs-tcl-ch8'; then
    fail 'Another LFS make/check/test/install process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks"
lfs_acquire_writer_lock "$DATA"
exec >"$LOG" 2>&1

printf 'Building and installing LFS Chapter 8 Tcl 8.6.16.\n'
printf 'LFS root: %s\nWork root: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX \
    /bin/bash -c '
        set -Eeuo pipefail
        work_root="$1"
        mapfile -t expected_src < <(awk '\''$2 == "tcl8.6.16-src.tar.gz" { print }'\'' /sources/md5sums)
        mapfile -t expected_html < <(awk '\''$2 == "tcl8.6.16-html.tar.gz" { print }'\'' /sources/md5sums)
        test "${#expected_src[@]}" -eq 1
        test "${#expected_html[@]}" -eq 1
        printf "%s\\n" "${expected_src[0]}" "${expected_html[0]}" | (cd /sources && md5sum --check -)

        mkdir -pv "$work_root"
        tar -xf /sources/tcl8.6.16-src.tar.gz -C "$work_root"
        srcdir="$work_root/tcl8.6.16"
        cd "$srcdir"
        cd unix
        ./configure --prefix=/usr \
                    --mandir=/usr/share/man \
                    --disable-rpath
        make -j4

        sed -e "s|$srcdir/unix|/usr/lib|" \
            -e "s|$srcdir|/usr/include|" \
            -i tclConfig.sh
        sed -e "s|$srcdir/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
            -e "s|$srcdir/pkgs/tdbc1.1.10/generic|/usr/include|" \
            -e "s|$srcdir/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|" \
            -e "s|$srcdir/pkgs/tdbc1.1.10|/usr/include|" \
            -i pkgs/tdbc1.1.10/tdbcConfig.sh
        sed -e "s|$srcdir/unix/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" \
            -e "s|$srcdir/pkgs/itcl4.3.2/generic|/usr/include|" \
            -e "s|$srcdir/pkgs/itcl4.3.2|/usr/include|" \
            -i pkgs/itcl4.3.2/itclConfig.sh

        make install
        chmod 644 /usr/lib/libtclstub8.6.a
        chmod u+w /usr/lib/libtcl8.6.so
        make install-private-headers
        ln -sfv tclsh8.6 /usr/bin/tclsh
        mv -v /usr/share/man/man3/Thread.3 /usr/share/man/man3/Tcl_Thread.3

        cd "$srcdir"
        tar -xf /sources/tcl8.6.16-html.tar.gz --strip-components=1
        mkdir -pv /usr/share/doc/tcl-8.6.16
        cp -rv ./html/* /usr/share/doc/tcl-8.6.16/

        test "$(printf "%s\\n" "puts [info patchlevel]" | /usr/bin/tclsh8.6)" = "8.6.16"
        test -e /usr/include/tcl.h
        test -e /usr/lib/libtclstub8.6.a
        test -e /usr/share/doc/tcl-8.6.16/contents.htm
        printf "Installed native Tcl 8.6.16.\\n"
    ' tcl-ch8 "$WORK_ROOT"

printf '\nFinished: %s\nStatus: PASS\nLog: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" "$LOG"
