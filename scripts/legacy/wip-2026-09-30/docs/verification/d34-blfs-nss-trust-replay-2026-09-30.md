# D34 BLFS NSS and trust replay — 30 September 2026

## Result

The NVMe D34 candidate now has NSS 3.115.0, NSPR 4.37, and the p11-kit trust integration. The successful NSS replay is `nss-20260930T083346Z-7818ca3a` (builder exit 0, 54,701 Btrfs events, 239,359,147-byte incremental stream). The trust integration replay is `nss-trust-integration-20260930T083815Z-3e0cb081` (builder exit 0, 9 events, 581-byte stream). Its output snapshot UUID is `a06719e8-b5f7-4844-92fd-76ed4cb8e2f2`, subvolume ID 692.

The trust configuration links `/usr/lib/libnssckbi.so` to `pkcs11/p11-kit-trust.so`, following the [BLFS 12.4 NSS instructions](https://www.linuxfromscratch.org/blfs/view/12.4-systemd/postlfs/nss.html). The reconciled ledger at `/home/yrslf/alpbahOS-nvme/d34-candidates/d34-replay-runs/nss-trust-integration-20260930T083815Z-3e0cb081/d34-ownership-ledger.json` is `COMPLETE`: all 79 official Chapter 8 packages and 23 supplemental steps are represented, with 4,966,087 path events and 58,362 final path owners. A root-authorized read-only walk found every ledger-owned path in the final candidate. The key NSS libraries, headers, `nss-config`, `certutil`, `pk12util`, pkg-config file, p11-kit trust module, and trust symlink exist.

## Implementation

- Added the BLFS NSS 3.115 builder and p11-kit trust integration configuration to the D34 runner/reconciler.
- Builder uses the BLFS standalone patch, 64-bit mode, NSPR headers, system zlib, and skips checksum calculation and upstream tests per the standing instruction.
- Fixed NSS install layout based on observed output: distribution libraries/binaries are in `dist/<target>`, while generated headers are under `dist/public` and `dist/private`.
- Copied distribution symlink targets into the staged root and checked the installed NSS version and shared-library dependencies.
- Focused D34 tests passed: 32 tests across supplemental reconciliation, candidate preflight, and builder wiring. `bash -n` and Python compilation also passed.

## Failed attempts and boundaries

Earlier failed NSS replay runs remain preserved and are excluded from the ownership ledger. The errors exposed an incorrect 32-bit build flag, stale assumptions about NSS header locations, and distribution symlinks that needed dereferencing; the final successful run resolves those issues.

This work changes only the NVMe D34 candidate; the active HDD `/mnt/lfs` and M10 ISO were not changed. NSS upstream tests and checksums were not run. WPA supplicant and NetworkManager are not yet present in this candidate, so M06 network management and M06–M10 acceptance remain open.
