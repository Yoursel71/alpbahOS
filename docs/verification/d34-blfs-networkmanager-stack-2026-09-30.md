# D34 BLFS NetworkManager stack replay — 30 September 2026

## Result

The NVMe D34 candidate now contains the wired/wireless stack in dependency order: libndp 1.9, NSPR 4.37, NSS 3.115.0, NSS p11-kit trust integration, D-Bus-enabled WPA Supplicant 2.11, libxml2 2.14.5, libxslt 1.1.43, and NetworkManager 1.54.0. NetworkManager uses NSS crypto and its Wi-Fi device plugin.

Successful NetworkManager replay: `networkmanager-20260930T085619Z-80ba25ab`, builder exit 0, 36,696 Btrfs events, 154,592,259-byte incremental stream. Output snapshot UUID `962acc41-0fe8-8144-aeba-feee0a1a7494`, subvolume ID 716. Its systemd service is enabled in the candidate.

The final ownership ledger at `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/networkmanager-20260930T085619Z-80ba25ab/d34-ownership-ledger.json` is `COMPLETE`: 79/79 official Chapter 8 packages, 27 supplemental steps, 5,076,796 path events, and 58,942 final path owners. A root-authorized read-only audit found zero missing owned paths. `NetworkManager`, `nmcli`, `nm-online`, the Wi-Fi plugin, systemd unit/enablement symlink, NetworkManager configuration and Polkit rule, WPA D-Bus service, NSS trust link, and `xsltproc` exist in the final snapshot.

## Implementation and checks

The supplemental replay chain includes separate libxml2 and libxslt builds, because the clean D34 candidate did not inherit target-rootfs prerequisites from the older HDD install. BLFS 12.4's libxml2 recipe was used without optional ICU support; libxslt 1.1.43 and NetworkManager 1.54.0 then built successfully. NetworkManager uses NSS crypto, systemd session tracking, nmcli, and the WPA Supplicant D-Bus interface. `nmtui` was disabled because newt is not present in this candidate. Its `netdev` Polkit rule is installed; user/group membership and a graphical applet are outside this replay.

Thirty-six targeted D34 reconciliation, preflight, and builder-wiring tests passed. Shell syntax, Python compilation, and `git diff --check` passed. NetworkManager upstream tests and checksums were not run.

Three failed NetworkManager replay attempts remain preserved and excluded from the ledger: `networkmanager-20260930T085015Z-4385a596` had an incorrect libndp header path; `networkmanager-20260930T085054Z-4da72cf4` used the wrong Meson `tests` option value; `networkmanager-20260930T085118Z-997cb8ac` exposed missing `xsltproc`/libxml2/libxslt prerequisites in the candidate. The successful run follows the added libxml2 and libxslt replays.

This proves package presence and configuration in the NVMe D34 candidate. It does not prove live Wi-Fi association, Plasma network applet behavior, inclusion in the M10 ISO, Ventoy boot, or M06–M10 release acceptance. The active HDD LFS root and existing ISO were not changed.
