#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, section 8.60.1: Meson-1.12.0 (also writes the 32-bit cross and native files).
set -euo pipefail

PKG=meson-1.12.0.tar.gz
DIR=meson-1.12.0

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.60.1 Installation of Meson
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson

# Multilib cross and native files used by the 32-bit builds (kmod, systemd, dbus) (book).
mkdir -pv /usr/share/meson/cross
mkdir -pv /usr/share/meson/native
for i in {cross/lib32,native/x86}; do
    cat > /usr/share/meson/$i << "EOF"
[binaries]
c = ['gcc', '-m32']
cpp = ['g++', '-m32']
rust = ['rustc', '--target', 'i686-unknown-linux-gnu']
pkg-config = 'i686-pc-linux-gnu-pkg-config'
ar = '/usr/bin/ar'
strip = '/usr/bin/strip'
cups-config = 'cups-config'
llvm-config = 'llvm-config'
exe_wrapper = ''

[built-in options]
libdir = 'lib32'

[properties]
sizeof_void* = 4
sizeof_long = 4

[host_machine]
system = 'linux'
subsystem = 'linux'
kernel = 'linux'
cpu_family = 'x86'
cpu = 'i686'
endian = 'little'
EOF
done

cd /sources
rm -rf "$DIR"
echo "OK 58-meson"
