#!/bin/bash
# CONTEXT: chroot
# REBUILD-R2 chapter 11: release files (book theend.html shape), AlpbahOS branding.
# The repo had no existing os-release or PRETTY_NAME values to copy (grep for os-release, PRETTY_NAME
# and alpbahos found only the live-iso and build scripts), so the values are set here.
set -euo pipefail

cat > /etc/lfs-release << "EOF"
13.1-systemd-R2
EOF

cat > /etc/lsb-release << "EOF"
DISTRIB_ID="AlpbahOS"
DISTRIB_RELEASE="13.1-systemd-R2"
DISTRIB_CODENAME="rebuild-r2"
DISTRIB_DESCRIPTION="AlpbahOS 13.1-systemd R2 (LFS 13.1 base)"
EOF

cat > /etc/os-release << "EOF"
NAME="AlpbahOS"
VERSION="13.1-systemd R2 (REBUILD-R2)"
ID=alpbahos
ID_LIKE=lfs
VERSION_ID="13.1-r2"
PRETTY_NAME="AlpbahOS 13.1-systemd R2"
EOF

chmod 644 /etc/lfs-release /etc/lsb-release /etc/os-release
grep -qx 'ID=alpbahos' /etc/os-release
grep -qx 'ID_LIKE=lfs' /etc/os-release
grep -qx 'DISTRIB_ID="AlpbahOS"' /etc/lsb-release
echo "OK 01-release-files"
