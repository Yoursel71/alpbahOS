#!/bin/bash
# CONTEXT: chroot
# Multilib LFS 13.1-systemd, chapter 9, "General Network Configuration" (book page network.html).
# Approved deviation: systemd-networkd with DHCP on every ethernet interface (en* and eth*), not a
# static address. The book's 99-default.link (null) and 10-ether0.link steps are not written: the
# null link would switch off predictable interface names, and the en* match relies on them.
# resolv.conf: the book's systemd-resolved stub link (/etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf).
set -euo pipefail

mkdir -pv /etc/systemd/network
cat > /etc/systemd/network/10-eth-dhcp.network << "EOF"
[Match]
Name=en* eth*

[Network]
DHCP=ipv4

[DHCPv4]
UseDomains=true
EOF

systemctl enable systemd-networkd.service systemd-resolved.service

# Book: the wait-online unit delays boot until a link is up; not wanted on this DHCP setup.
# Disabled after the enable: systemd-networkd pulls wait-online back in when it is enabled.
systemctl disable systemd-networkd-wait-online

ln -svfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

test -f /etc/systemd/network/10-eth-dhcp.network
test "$(readlink /etc/resolv.conf)" = /run/systemd/resolve/stub-resolv.conf
echo "OK 01-network"
