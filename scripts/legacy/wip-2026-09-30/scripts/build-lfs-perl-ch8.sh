#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lfs-build-guard.sh"

readonly LFS=/mnt/lfs
readonly DATA=/mnt/alpbahOS-data/alpbahOS-build
readonly STAMP="$(date -u '+%Y%m%dT%H%M%S%NZ')"
readonly WORK_ROOT="/sources/perl-5.42.0-ch8-$STAMP"
readonly SOURCE_ROOT="$WORK_ROOT/perl-5.42.0"
readonly LOG_DIR="$DATA/logs/lfs-12.4-systemd"
readonly LOG="${ALPBAHOS_D34_LOG_PATH:-$LOG_DIR/perl-ch8-$STAMP.log}"
readonly CHROOT_LOG="$WORK_ROOT/perl-ch8.log"
readonly HOST_CHROOT_LOG="$LFS$CHROOT_LOG"
readonly BACKUP_DIR="$DATA/backups/perl-pass2-before-final-$STAMP"
readonly BACKUP_ARCHIVE="$BACKUP_DIR/perl-pass2-files.tar"
readonly MANIFEST0="$BACKUP_DIR/files.list0"
readonly MANIFEST="$BACKUP_DIR/files.list"

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
[[ -r "$LFS/sources/perl-5.42.0.tar.xz" ]] || fail 'The Perl 5.42.0 source archive is missing.'
[[ ! -e "$LFS$WORK_ROOT" ]] || fail "Refusing to overwrite a previous Perl work tree: $WORK_ROOT"
sudo -n true || fail 'Non-interactive sudo is unavailable.'
if ps -eo comm= | awk '$1 == "make" || $1 == "expect" || $1 == "runtest" { found=1 } END { exit found ? 0 : 1 }'; then
    fail 'A make/check/test process is active.'
fi

mkdir -p "$LOG_DIR" "$DATA/locks" "$BACKUP_DIR"
lfs_acquire_writer_lock "$DATA"
exec > >(tee "$LOG") 2>&1

printf 'Building LFS Chapter 8 Perl 5.42.0.\n'
printf 'LFS root: %s\nIsolated source tree: %s\nStarted: %s\n\n' "$LFS" "$WORK_ROOT" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
printf 'Using the existing source archive without checksum work, as requested.\n'
printf 'The LFS page lists TEST_JOBS=$(nproc) make test_harness as an optional test; it is not being run.\n'

(
    cd "$LFS"
    for path in usr/lib/perl5 usr/share/perl5 usr/share/man/man1 usr/share/man/man3; do
        if [[ -e "$path" || -L "$path" ]]; then printf '%s\0' "$path"; fi
    done
    find usr/lib -maxdepth 1 \( -type f -o -type l \) -name 'libperl.so*' -print0 2>/dev/null || true
    for program in corelist cpan enc2xs encguess h2ph h2xs instmodsh json_pp libnetcfg \
        perl perl5.42.0 perlbug perldoc perlivp perlthanks piconv pl2pm pod2html pod2man \
        pod2text pod2usage podchecker podselect prove ptar ptardiff ptargrep shasum splain \
        xsubpp zipdetails; do
        if [[ -e "usr/bin/$program" || -L "usr/bin/$program" ]]; then printf 'usr/bin/%s\0' "$program"; fi
    done
) | sort -zu > "$MANIFEST0"
tr '\0' '\n' < "$MANIFEST0" > "$MANIFEST"
if [[ -s "$MANIFEST0" ]]; then
    sudo -n tar --create --file="$BACKUP_ARCHIVE" --numeric-owner --acls --xattrs \
        -C "$LFS" --null --files-from="$MANIFEST0"
    sudo -n chown "$(id -u):$(id -g)" "$BACKUP_ARCHIVE"
    tar --list --file="$BACKUP_ARCHIVE" > "$BACKUP_DIR/archive.list"
    [[ -s "$BACKUP_DIR/archive.list" ]] || fail 'The Perl Pass 2 backup archive is empty.'
    printf 'Existing Perl-path backup: %s bytes\n' "$(stat -c '%s' "$BACKUP_ARCHIVE")"
else
    printf 'No existing Perl-path files were found.\n' | tee "$BACKUP_DIR/no-preexisting-files.txt"
fi
printf 'Pre-existing top-level path count: %s\n' "$(wc -l < "$MANIFEST")"

sudo -n chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM=dumb PATH=/usr/bin:/usr/sbin LC_ALL=POSIX MAKEFLAGS=-j4 \
    /bin/bash -s -- "$WORK_ROOT" "$SOURCE_ROOT" "$CHROOT_LOG" <<'CHROOT'
set -Eeuo pipefail
work_root="$1"
source_root="$2"
build_log="$3"
mkdir -pv "$work_root"
exec > >(tee "$build_log") 2>&1

tar -xf /sources/perl-5.42.0.tar.xz -C "$work_root"
[[ -f "$source_root/Configure" ]] || { printf 'Perl Configure script is missing.\n' >&2; exit 1; }
cd "$source_root"
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des \
    -D prefix=/usr \
    -D vendorprefix=/usr \
    -D privlib=/usr/lib/perl5/5.42/core_perl \
    -D archlib=/usr/lib/perl5/5.42/core_perl \
    -D sitelib=/usr/lib/perl5/5.42/site_perl \
    -D sitearch=/usr/lib/perl5/5.42/site_perl \
    -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
    -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
    -D man1dir=/usr/share/man/man1 \
    -D man3dir=/usr/share/man/man3 \
    -D pager='/usr/bin/less -isR' \
    -D useshrplib \
    -D usethreads > "$work_root/configure.log" 2>&1

if make -j4 > "$work_root/compile.log" 2>&1; then
    printf 'PERL_BUILD_RESULT=PASS\n'
else
    status=$?
    printf 'PERL_BUILD_RESULT=FAIL exit=%s\n' "$status"
    tail -n 80 "$work_root/compile.log"
    exit "$status"
fi

make -j1 install
unset BUILD_ZLIB BUILD_BZIP2

/usr/bin/perl -e 'print "Perl $^V\n"'
/usr/bin/perl -Mthreads -e 'print "threads ", threads->VERSION, "\n"'
/usr/bin/perl -MCompress::Raw::Zlib -MCompress::Raw::Bzip2 -e 'print "system compression modules available\n"'
for program in corelist cpan enc2xs encguess h2ph h2xs instmodsh json_pp libnetcfg \
    perl perl5.42.0 perlbug perldoc perlivp perlthanks piconv pl2pm pod2html pod2man \
    pod2text pod2usage podchecker prove ptar ptardiff ptargrep shasum splain \
    xsubpp zipdetails; do
    [[ -x "/usr/bin/$program" ]] || { printf 'Missing installed program: %s\n' "$program" >&2; exit 1; }
done
[[ -d /usr/lib/perl5/5.42/core_perl ]]
[[ -e /usr/lib/perl5/5.42/core_perl/CORE/libperl.so ]]
printf 'PERL_FINAL_INSTALL=PASS\nPERL_WORK_TREE=%s\n' "$source_root"
CHROOT

printf '\nPerl Chapter 8 build/install completed; test suite was not run.\n'
printf 'Build/install log: %s\nPre-install backup: %s\nFinished: %s\n' \
    "$HOST_CHROOT_LOG" "$BACKUP_DIR" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
