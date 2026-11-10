#!/usr/bin/env python3
"""REBUILD-R21: alpbahOS-owned system files for the firewall (FIREWALL-01, D153) and zram swap (ZRAM-01, D152).

Firewall: iptables (legacy, BLFS 13.1) rule files loaded by alpbahos-firewall.service before the network comes up.
  Inbound: default DROP; accepted are loopback, replies to our own traffic (conntrack RELATED,ESTABLISHED), DHCP
  replies (IPv4 67->68, IPv6 547->546) and the ICMPv6 messages that IPv6 needs (neighbour discovery, router
  advertisements). Ping (echo request) and every service port are dropped. Forward: DROP. Outbound: ACCEPT.
  Stopping the unit loads the open rule files (ACCEPT everywhere), so `systemctl stop alpbahos-firewall` really opens.
  The unit is not stopped at shutdown (no Conflicts=shutdown.target), so the rules stay until the end.
Zram: alpbahos-zram.service runs /usr/libexec/alpbahos/zram-swap at boot: one zram device of half the RAM (at most
  4 GiB), zstd, as swap with priority 100. Only util-linux (zramctl, mkswap, swapon) and the kernel module are used.
Usage: product-r21.py <STAGE_DIR>
"""
import os
import sys

STAGE = sys.argv[1]
V4 = """# alpbahOS firewall, IPv4 (D153). Loaded by alpbahos-firewall.service with iptables-restore.
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT
COMMIT
"""
V6 = """# alpbahOS firewall, IPv6 (D153). Loaded by alpbahos-firewall.service with ip6tables-restore.
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -i lo -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type neighbour-solicitation -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type neighbour-advertisement -j ACCEPT
-A INPUT -p ipv6-icmp --icmpv6-type router-advertisement -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p udp --sport 547 --dport 546 -j ACCEPT
COMMIT
"""
OPEN = """# alpbahOS firewall stopped: everything accepted (loaded when alpbahos-firewall.service stops).
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
COMMIT
"""
FW_UNIT = """[Unit]
Description=alpbahOS firewall (inbound connections blocked)
Documentation=file:///etc/alpbahos/firewall/rules.v4
DefaultDependencies=no
After=local-fs.target systemd-modules-load.service
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/iptables-restore /etc/alpbahos/firewall/rules.v4
ExecStart=/usr/sbin/ip6tables-restore /etc/alpbahos/firewall/rules.v6
ExecReload=/usr/sbin/iptables-restore /etc/alpbahos/firewall/rules.v4
ExecReload=/usr/sbin/ip6tables-restore /etc/alpbahos/firewall/rules.v6
ExecStop=/usr/sbin/iptables-restore /etc/alpbahos/firewall/open.v4
ExecStop=/usr/sbin/ip6tables-restore /etc/alpbahos/firewall/open.v6

[Install]
WantedBy=multi-user.target
"""
ZRAM = """#!/bin/sh
# alpbahOS zram swap (D152): one compressed swap device in RAM. start | stop
set -eu
case "${1:-start}" in
start)
    modprobe zram
    MEM_KIB=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    SIZE_KIB=$((MEM_KIB / 2))
    [ "$SIZE_KIB" -le 4194304 ] || SIZE_KIB=4194304
    DEV=$(zramctl --find --size "${SIZE_KIB}KiB" --algorithm zstd)
    mkswap --label alpbahos-zram "$DEV" > /dev/null
    swapon --priority 100 "$DEV"
    echo "zram swap on $DEV: ${SIZE_KIB} KiB, zstd"
    ;;
stop)
    for DEV in $(swapon --noheadings --raw --show=NAME | grep '^/dev/zram' || true); do
        swapoff "$DEV"
        zramctl --reset "$DEV"
    done
    ;;
*) echo "usage: $0 start|stop" >&2; exit 2 ;;
esac
"""
ZRAM_UNIT = """[Unit]
Description=alpbahOS compressed swap in RAM (zram)
DefaultDependencies=no
After=systemd-modules-load.service
Before=swap.target shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/alpbahos/zram-swap start
ExecStop=/usr/libexec/alpbahos/zram-swap stop

[Install]
WantedBy=swap.target
"""
FILES = {
    "etc/alpbahos/firewall/rules.v4": (V4, 0o644),
    "etc/alpbahos/firewall/rules.v6": (V6, 0o644),
    "etc/alpbahos/firewall/open.v4": (OPEN, 0o644),
    "etc/alpbahos/firewall/open.v6": (OPEN, 0o644),
    "usr/lib/systemd/system/alpbahos-firewall.service": (FW_UNIT, 0o644),
    "usr/libexec/alpbahos/zram-swap": (ZRAM, 0o755),
    "usr/lib/systemd/system/alpbahos-zram.service": (ZRAM_UNIT, 0o644),
}
for rel, (text, mode) in FILES.items():
    dst = os.path.join(STAGE, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    os.chmod(dst, mode)
    print("wrote " + rel)
