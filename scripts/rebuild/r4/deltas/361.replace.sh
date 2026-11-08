#!/bin/bash
# REBUILD-R4 361 rustc-1.97.1 (13.1 general/rust.html): bootstrap.toml and x.py commands from the page.
# The page's docs fix and completion steps are skipped; tests are not run (the book's test suite is long).
# stage0 is downloaded by x.py (the page says so). Built at jobs=8 (16 ran out of memory elsewhere).
export LANG=C LC_ALL=C
set -eo pipefail
export XORG_PREFIX=/usr
export XORG_CONFIG="--prefix=$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var --disable-static"
export KF6_PREFIX=/usr
as_root() { "$@"; }; export -f as_root
cd /sources/blfs-build 2>/dev/null || { mkdir -p /sources/blfs-build && cd /sources/blfs-build; }
TB="/sources/blfs-src/rustc-1.97.1-src.tar.xz"; [ -f "$TB" ] || { echo "KAYNAK_YOK $TB"; exit 2; }
PKG=$(tar -tf "$TB" | sed -n 1p | cut -d/ -f1); rm -rf "$PKG"; tar -xf "$TB"; cd "$PKG"
export LIBSSH2_SYS_USE_PKG_CONFIG=1
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
# --- blok 1: bootstrap.toml and build ---
cat > bootstrap.toml << 'EOF'
change-id = 154587
[llvm]
link-shared = true
targets = "X86"
[build]
description = "for BLFS 13.1"
docs = false
tools = ["cargo", "clippy", "rustdoc", "rustfmt", "src"]
[install]
prefix = "/opt/rustc-1.97.1"
docdir = "share/doc/rustc-1.97.1"
[rust]
channel = "stable"
lto = "thin"
codegen-units = 1
llvm-bitcode-linker = false
[target.x86_64-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
[target.i686-unknown-linux-gnu]
llvm-config = "/usr/bin/llvm-config"
EOF
./x.py build --jobs 8
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 1 rc=$_rc"; exit 1; }
# --- blok 2: install ---
as_root mkdir -pv /opt/rustc-1.97.1 &&
as_root ln -svfn rustc-1.97.1 /opt/rustc &&
as_root ./x.py install
_rc=$?; [ "$_rc" -eq 0 ] || { echo "BLOK-FAIL 2 rc=$_rc"; exit 1; }
as_root /sbin/ldconfig
cd /sources/blfs-build && rm -rf "$PKG"
