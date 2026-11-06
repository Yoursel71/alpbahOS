#!/bin/bash
# rebuild-gmp.sh -- run INSIDE the LFS chroot, as root.
#
# Rebuilds GMP 6.3.0 with the LFS 12.4-systemd book options (chapter 8.21), made generic:
#   --build=x86_64-pc-linux-gnu  stops config.guess from naming the host CPU (zen3)
#   --enable-fat                 runtime CPU selection for the assembly routines
#   CFLAGS/CXXFLAGS generic      -O2 -march=x86-64 -mtune=generic
# Book page: https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/gmp.html
# Reason: docs/verification/sigill-cpu-baseline-2026-11-06.md (sections 5.2 and 6.1).
#
# Book deviations (documented in README.md):
#   - make html / make install-html are skipped (docs only, not needed for the ISA fix).
#   - CXXFLAGS is set too, because GMP's configure otherwise takes -march=znver3 for libgmpxx.
set -euo pipefail
export LC_ALL=C

PKG=gmp
VER=6.3.0
TB=gmp-6.3.0.tar.xz
TB_MD5=956dc04e864001a9c22429f761f2c283   # LFS 12.4 md5sums list (also in docs/verification/m04-lfs-12.4-systemd-ch8-source-md5.json)
GENERIC_FLAGS="-O2 -march=x86-64 -mtune=generic"
MIN_PASS=199                              # book: "Ensure that at least 199 tests in the test suite passed"
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

# 2. Source checksum.
log "checksum $TB"
echo "$TB_MD5  $TB" | (cd /sources && md5sum -c -)

# 3. Fresh build tree.
mkdir -p "$OUTDIR"
mkdir "$BUILD"
tar -xf "/sources/$TB" -C "$BUILD" --strip-components=1
cd "$BUILD"
log "build tree: $BUILD"

# 4. Book step: compatibility edit for gcc-15 and later.
sed -i '/long long t1;/,+1s/()/(...)/' configure

# 5. Configure. Book: ./configure --prefix=/usr --enable-cxx --disable-static --docdir=/usr/share/doc/gmp-6.3.0
#    Added: --build (pin CPU name), --enable-fat (generic build with runtime selection).
#    Flags: generic CFLAGS and CXXFLAGS (see GENERIC_FLAGS).
export CFLAGS="$GENERIC_FLAGS" CXXFLAGS="$GENERIC_FLAGS"
log "configure (CFLAGS=$CFLAGS)"
./configure --prefix=/usr \
            --build=x86_64-pc-linux-gnu \
            --enable-cxx \
            --enable-fat \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0

# 6. Gate before any build or install: no znver3 anywhere in config.log.
ZN=$(grep -c znver3 config.log || true)
[[ $ZN -eq 0 ]] || die "config.log mentions znver3 ($ZN lines); host CPU flags leaked"
log "config.log: znver3 lines = 0; -march=x86-64 lines = $(grep -c -- '-march=x86-64' config.log || true)"

# 7. Build. Book: make (make html skipped, see header).
log "make"
make

# 8. Test. Book: CRITICAL. Must not be skipped. Need >= MIN_PASS PASS and no FAIL/XPASS/ERROR.
log "make check (critical)"
make check 2>&1 | tee "$OUTDIR/$PKG-check.log"
PASSN=$(awk '/# PASS:/{total+=$3} END{print total+0}' "$OUTDIR/$PKG-check.log")
BADN=$(awk '/# (FAIL|XPASS|ERROR):/{total+=$3} END{print total+0}' "$OUTDIR/$PKG-check.log")
log "PASS total = $PASSN (book minimum $MIN_PASS); FAIL+XPASS+ERROR total = $BADN"
[[ $PASSN -ge $MIN_PASS ]] || die "GMP test suite: only $PASSN PASS (need >= $MIN_PASS)"
[[ $BADN -eq 0 ]] || die "GMP test suite: $BADN FAIL/XPASS/ERROR"

# 9. Keep the installed GMP files so the old library can be restored.
shopt -s nullglob
OLD=(/usr/lib/libgmp.so* /usr/lib/libgmpxx.so* /usr/include/gmp.h /usr/include/gmpxx.h)
mkdir -p "$SAVE"
if ((${#OLD[@]})); then cp -a "${OLD[@]}" "$SAVE"/; fi
log "saved previous GMP files to $SAVE (${#OLD[@]} entries)"

# 10. Install. Book: make install (install-html skipped, see header).
log "make install"
make install
ls -l /usr/lib/libgmp.so* /usr/lib/libgmpxx.so*

# 11. Marker read by rebuild-mpfr.sh: this build directory was installed successfully.
echo "installed $(date -Is) $BUILD" > "$BUILD/INSTALLED-OK"

log "DONE gmp $VER rebuilt (generic, --enable-fat). Next: rebuild-mpfr.sh, then audit-isa.sh on the host."
