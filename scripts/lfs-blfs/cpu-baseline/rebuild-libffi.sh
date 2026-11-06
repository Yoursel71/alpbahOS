#!/bin/bash
# rebuild-libffi.sh -- run INSIDE the LFS chroot, as root.
#
# Rebuilds libffi 3.5.2 with the LFS 12.4-systemd book options (chapter 8.50),
# except --with-gcc-arch=x86-64 instead of --with-gcc-arch=native.
# Book page: https://www.linuxfromscratch.org/lfs/view/12.4-systemd/chapter08/libffi.html
# Reason: docs/verification/sigill-cpu-baseline-2026-11-06.md (sections 5.1 and 6.1).
#
# Log: the caller redirects output (see README.md). Test summary: /sources/cpu-baseline-build/.
set -euo pipefail
export LC_ALL=C

PKG=libffi
VER=3.5.2
TB=libffi-3.5.2.tar.gz
TB_MD5=92af9efad4ba398995abf44835c5d9e9   # LFS 12.4 md5sums list (also in docs/verification/m04-lfs-12.4-systemd-ch8-source-md5.json)
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

# 3. Fresh build tree (never reuse an old one).
mkdir -p "$OUTDIR"
mkdir "$BUILD"
tar -xf "/sources/$TB" -C "$BUILD" --strip-components=1
cd "$BUILD"
log "build tree: $BUILD"

# 4. Configure. Book: ./configure --prefix=/usr --disable-static --with-gcc-arch=native
#    Only change: --with-gcc-arch=x86-64 (no host CPU detection).
log "configure"
./configure --prefix=/usr \
            --disable-static \
            --with-gcc-arch=x86-64

# 5. Build.
log "make"
make

# 6. Flag check. configure puts the flags in the build-dir Makefile (x86_64-pc-linux-gnu/).
for mk in Makefile x86_64-pc-linux-gnu/Makefile; do
  [[ -f $mk ]] || continue
  if grep -q -- '-march=native' "$mk"; then
    die "$mk still contains -march=native"
  fi
done
[[ -f x86_64-pc-linux-gnu/Makefile ]] || die "build-dir Makefile not found (x86_64-pc-linux-gnu/Makefile)"
grep -q -- '-march=x86-64' x86_64-pc-linux-gnu/Makefile || die "build-dir Makefile has no -march=x86-64"
log "flags in build-dir Makefile:"
grep -- '-march' x86_64-pc-linux-gnu/Makefile || true

# 7. Test. Book: make check. The libffi summary is kept with the log.
log "make check"
make check 2>&1 | tee "$OUTDIR/$PKG-check.log"
SUM=$(find . -name libffi.sum -path '*testsuite*' -print -quit)
[[ -n $SUM ]] || die "testsuite/libffi.sum not found"
cp "$SUM" "$OUTDIR/$PKG-testsuite.sum"
grep -E '^# of (expected passes|unexpected failures|unsupported tests|unresolved testcases)' "$SUM" \
  | tee "$OUTDIR/$PKG-check-summary.txt"
UNEXP=$(awk '/^# of unexpected failures/{s+=$NF} END{print s+0}' "$SUM")
[[ $UNEXP -eq 0 ]] || die "libffi test suite: $UNEXP unexpected failures (see $OUTDIR/$PKG-check.log)"

# 8. Keep the installed libffi files so the old library can be restored.
shopt -s nullglob
OLD=(/usr/lib/libffi.so* /usr/lib/libffi.la)
mkdir -p "$SAVE"
if ((${#OLD[@]})); then cp -a "${OLD[@]}" "$SAVE"/; fi
log "saved previous libffi files to $SAVE (${#OLD[@]} entries)"

# 9. Install. Book: make install.
log "make install"
make install
ls -l /usr/lib/libffi.so*
sha256sum /usr/lib/libffi.so.8.2.0

log "DONE libffi $VER rebuilt (generic x86-64). Run audit-isa.sh on the host (see README.md)."
