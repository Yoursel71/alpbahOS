#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1, chapter 8, sections 8.31.1-8.31.2: Shadow-4.20.2.
# Book steps that prompt for a password (passwd root) are not run here; see the verification note.
set -euo pipefail

PKG=shadow-4.20.2.tar.xz
DIR=shadow-4.20.2

cd /sources
rm -rf "$DIR"
tar -xf "$PKG"
cd "$DIR"

# 8.31.1 Installation of Shadow
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;

sed -e 's:#ENCRYPT_METHOD SHA512:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:' \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \
    -i etc/login.defs

# The file /usr/bin/passwd must exist before configure (book).
touch /usr/bin/passwd
./configure --sysconfdir=/etc \
            --disable-static \
            --with-{b,yes}crypt \
            --without-libbsd \
            --disable-logind \
            --with-group-name-max-length=32
make
make exec_prefix=/usr install
make -C man install-man

# 8.31.2 Configuring Shadow
pwconv
grpconv
mkdir -p /etc/default
useradd -D --gid 999
sed -i '/MAIL/s/yes/no/' /etc/default/useradd
touch /etc/sub{u,g}id

# 8.31.3 Setting the Root Password: skipped (interactive). Set by the operator or the installer, never stored in the repo.

cd /sources
rm -rf "$DIR"
echo "OK 29-shadow"
