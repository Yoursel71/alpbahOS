#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1-systemd, chapter 9, "Customizing systemd" (book page systemd-custom.html): the
# defaults the book sets. Not written: the book's foobar.service example and the coredump MaxUse
# example, which are illustrations, not defaults.
set -euo pipefail

mkdir -pv /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/noclear.conf << EOF
[Service]
TTYVTDisallocate=no
EOF

# Book: /tmp is cleared by tmpfiles (q /tmp 1777 root root 10d); tmp.mount is masked, the tmpfiles copy is kept.
systemctl mask tmp.mount
mkdir -p /etc/tmpfiles.d
cp /usr/lib/tmpfiles.d/tmp.conf /etc/tmpfiles.d

test -L /etc/systemd/system/tmp.mount
test -f /etc/systemd/system/getty@tty1.service.d/noclear.conf
test -f /etc/tmpfiles.d/tmp.conf
echo "OK 03-systemd-custom"
