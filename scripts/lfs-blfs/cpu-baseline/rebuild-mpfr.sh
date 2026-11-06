#!/bin/bash
# rebuild-mpfr.sh -- run INSIDE the LFS chroot, as root. Run AFTER rebuild-gmp.sh.
#
# Rebuilds MPFR 4.2.2 with the LFS 12.4-systemd book options (chapter 8.22),
# with generic flags: CFLAGS="-O2 -march=x86-64 -mtune=generic".
# Book page: https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/mpfr.html
# Reason: docs/verification/sigill-cpu-baseline-2026-11-06.md (sections 5.2 and 6.1).
#
# Book deviation (documented in README.md): make html / make install-html are skipped.
set -euo pipefail
export LC_ALL=C

PKG=mpfr
VER=4.2.2
TB=mpfr-4.2.2.tar.xz
TB_MD5=7c32c39b8b6e3ae85f25156228156061   # LFS 12.4 md5sums list (also in docs/verification/m04-lfs-12.4-systemd-ch8-source-md5.json)
GENERIC_FLAGS="-O2 -march=x86-64 -mtune=generic"
MIN_PASS=198                              # book: "ensure that all 198 tests passed"
OUTDIR=/sources/cpu-baseline-build
STAMP=$(date +%Y%m%d-%H%M%S)
BUILD=$OUTDIR/$PKG-$VER-$STAMP
SAVE=$OUTDIR/$PKG-installed-before-$STAMP

log() { printf '[%s] %s\n' "$(date +%T)" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "ERROR: %s script stopped at line %s (exit %s)\n" "$PKG" "$LINENO" "$?" >&2' ERR

# 1. Environment: root inside an LFS system, source present, fresh build dir.
[[ "$(id -u)" -eq 0 ]] || die "must run as root inside the chroot"
if [[ ! -f /etc/lfs-release ]] && ! grep -q 'Linux From Scratch' /etc/os-release 2>/dev/null; then
  die "not an LFS system (no /etc/lfs-release and no LFS marker in /etc/os-release)"
fi
[[ -f /sources/$TB ]] || die "missing /sources/$TB"
[[ ! -e $BUILD ]] || die "build dir already exists: $BUILD (a fresh tree is required)"

# 2. Order: the newest GMP build must have been installed (rebuild-gmp.sh writes INSTALLED-OK).
shopt -s nullglob
GDIRS=("$OUTDIR"/gmp-6.3.0-*)
((${#GDIRS[@]})) || die "no GMP rebuild found in $OUTDIR; run rebuild-gmp.sh first"
GLAST=${GDIRS[-1]}
[[ -f $GLAST/INSTALLED-OK ]] || die "newest GMP build ($GLAST) was not installed; run rebuild-gmp.sh first"
[[ -f /usr/include/gmp.h ]] || die "/usr/include/gmp.h missing"

# 3. Source checksum.
log "checksum $TB"
echo "$TB_MD5  $TB" | (cd /sources && md5sum -c -)

# 4. Fresh build tree.
mkdir -p "$OUTDIR"
mkdir "$BUILD"
tar -xf "/sources/$TB" -C "$BUILD" --strip-components=1
cd "$BUILD"
log "build tree: $BUILD (after GMP build $GLAST)"

# 5. Configure. Book: ./configure --prefix=/usr --disable-static --enable-thread-safe --docdir=/usr/share/doc/mpfr-4.2.2
#    Flags: generic CFLAGS, the same string as the GMP build, so configure's GMP compatibility check matches.
export CFLAGS="$GENERIC_FLAGS"
log "configure (CFLAGS=$CFLAGS)"
./configure --prefix=/usr \
            --disable-static \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2

# 6. Gate before build/install: no znver3 in config.log.
ZN=$(grep -c znver3 config.log || true)
[[ $ZN -eq 0 ]] || die "config.log mentions znver3 ($ZN lines); host CPU flags leaked"
log "config.log: znver3 lines = 0; -march=x86-64 lines = $(grep -c -- '-march=x86-64' config.log || true)"

# 7. Build. Book: make (make html skipped, see header).
log "make"
make

# 8. Test. Book: all tests must pass (critical). Need >= MIN_PASS PASS and no FAIL/XPASS/ERROR.
log "make check (critical)"
make check 2>&1 | tee "$OUTDIR/$PKG-check.log"
TOTN=$(awk '/^# TOTAL:/{total+=$3} END{print total+0}' "$OUTDIR/$PKG-check.log")
PASSN=$(awk '/^# PASS:/{total+=$3} END{print total+0}' "$OUTDIR/$PKG-check.log")
BADN=$(awk '/^# (FAIL|XPASS|ERROR):/{total+=$3} END{print total+0}' "$OUTDIR/$PKG-check.log")
[[ $TOTN -gt 0 ]] || die "no automake summary (# TOTAL) in $OUTDIR/$PKG-check.log"
log "TOTAL = $TOTN, PASS = $PASSN (book: $MIN_PASS), FAIL+XPASS+ERROR = $BADN"
[[ $PASSN -ge $MIN_PASS ]] || die "MPFR test suite: only $PASSN PASS (need >= $MIN_PASS)"
[[ $BADN -eq 0 ]] || die "MPFR test suite: $BADN FAIL/XPASS/ERROR"

# 9. Keep the installed MPFR files so the old library can be restored.
OLD=(/usr/lib/libmpfr.so* /usr/include/mpfr.h /usr/include/mpf2mpfr.h)
mkdir -p "$SAVE"
if ((${#OLD[@]})); then cp -a "${OLD[@]}" "$SAVE"/; fi
log "saved previous MPFR files to $SAVE (${#OLD[@]} entries)"

# 10. Install. Book: make install (install-html skipped, see header).
log "make install"
make install
ls -l /usr/lib/libmpfr.so*
sha256sum /usr/lib/libmpfr.so.6.2.2

log "DONE mpfr $VER rebuilt (generic). Next: audit-isa.sh on the host (see README.md)."
