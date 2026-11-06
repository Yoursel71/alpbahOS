# D34 BLFS WPA Supplicant replay — 30 September 2026

## Result

WPA Supplicant 2.11 built with D-Bus control, nl80211/libnl, OpenSSL EAP support, and systemd units in the NVMe D34 candidate. The successful replay is `wpa_supplicant-20260930T084455Z-248bd16b`: builder exit 0, 8,726 Btrfs events, 34,855,865-byte incremental stream. Output snapshot UUID is `aed9b6cb-e7e8-f44f-9961-c92931cc73da`, subvolume ID 699.

The candidate contains `/usr/sbin/wpa_supplicant`, `wpa_cli`, `wpa_passphrase`, the `wpa_supplicant@.service` unit, D-Bus activation service, and D-Bus policy. Root-authorized read-only audit found all 58,372 paths represented by the reconciled ledger. Ledger result is `COMPLETE`: 79/79 official Chapter 8 packages, 24 supplemental steps, 4,975,986 path events, zero missing owned paths. NSS trust integration remains linked to the p11-kit trust module.

## Implementation and checks

The builder follows the [BLFS 12.4 WPA Supplicant recipe](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/basicnet/wpa_supplicant.html), with D-Bus options enabled because NetworkManager will control the supplicant. It installs the three binaries, systemd services, and D-Bus activation/policy files. BLFS states this package has no test suite; no checksum was calculated.

Thirty-three targeted D34 supplemental-reconciliation, preflight, and builder-wiring tests passed. Shell syntax, Python compilation, and `git diff --check` passed. Two failed replay attempts remain preserved and excluded from the ledger; the causes were a source subdirectory assumption in service installation.

This is still only the NVMe D34 candidate. NetworkManager has not yet been added; live Wi-Fi/runtime validation and M06–M10 release acceptance remain open. The active HDD root and M10 ISO were not changed.
