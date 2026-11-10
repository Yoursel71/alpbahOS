#!/usr/bin/env python3
"""REBUILD-R20 (NET-FW-01): NetworkManager configuration for the alpbahOS image (D147).

The BLFS NetworkManager page left two files in /etc/NetworkManager/conf.d that break NetworkManager on this base:
  dhcp.conf           dhcp=dhcpcd   -> dhcpcd is not installed; use NetworkManager's internal DHCP client.
  no-dns-update.conf  dns=none      -> /etc/resolv.conf is the systemd-resolved stub, so NetworkManager must hand the
                                       DHCP DNS servers to systemd-resolved (dns=systemd-resolved).
Both files are owned by the NetworkManager record; this record takes them over (REPLACE=1). The file names are kept so
the ownership moves cleanly; each file says what it does now. Idempotent.
Usage: nm-conf-r20.py <R4_ROOT> <STAGE_DIR>
"""
import os
import sys

R4, STAGE = sys.argv[1], sys.argv[2]
FILES = {
    "etc/NetworkManager/conf.d/dhcp.conf": (
        "# alpbahOS (D147): NetworkManager's internal DHCP client (dhcpcd is not installed).\n"
        "[main]\n"
        "dhcp=internal\n"
    ),
    "etc/NetworkManager/conf.d/no-dns-update.conf": (
        "# alpbahOS (D147): file name kept from the BLFS page. NetworkManager passes the DNS servers of each\n"
        "# connection to systemd-resolved; /etc/resolv.conf stays the resolved stub.\n"
        "[main]\n"
        "dns=systemd-resolved\n"
    ),
}
for rel, text in FILES.items():
    if not os.path.isfile(os.path.join(R4, rel)):
        raise SystemExit(rel + ": not in r4-root (expected the BLFS file)")
    dst = os.path.join(STAGE, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(text)
    print("wrote " + rel)
