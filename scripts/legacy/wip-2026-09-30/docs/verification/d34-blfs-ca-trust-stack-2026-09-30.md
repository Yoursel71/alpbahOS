# D34 BLFS CA trust stack replay — 30 September 2026

## Result and scope

The composite BLFS CA trust prerequisite builder passed on a private NVMe D34 snapshot: run `ca-trust-stack-20260930T074821Z-bd567c93`, 26,297 filesystem events, 126,129,256 bytes sent. It installs libtasn1 4.20.0, which 2.23, make-ca 1.16.1, and p11-kit 0.25.5, then builds Mozilla CA stores from upstream NSS `certdata.txt`. Because the existing builder installs these components as one ordered transaction, the D34 ledger records one explicitly named supplemental `ca-trust-stack` entry with all component versions in its version field.

## Evidence

- The final ledger is `COMPLETE`: 79 official LFS Chapter 8 packages, 16 supplemental entries, 4,880,285 total path events, and 57,813 final system-path owners.
- Root inspection found all 876 final-owned paths attributed to `ca-trust-stack` in the final read-only snapshot.
- Generated files include `/etc/ssl/certdata.txt` (1,375,075 bytes), `/etc/pki/tls/certs/ca-bundle.crt` (185,311 bytes), and `/etc/pki/anchors.md5sums`. The bundle contains 121 PEM certificates; p11-kit reports 172 CA anchors; `/etc/ssl/certs` contains 516 files/symlinks.
- The candidate's cURL made a TLS-verified HEAD request to Mozilla NSS certdata: HTTP 200, `ssl_verify_result=0`. The clean LFS candidate has no `/etc/resolv.conf`, so the test pinned the already host-resolved `hg-edge.mozilla.org` address `151.101.1.91`; this proves CA/TLS verification but not guest DNS.
- The initial replay `ca-trust-stack-20260930T074536Z-a6a94672` is preserved. make-ca's `-g` could not obtain a server revision in the target. The builder now fetches upstream `certdata.txt` on the Fedora host and invokes `make-ca -C /sources/mozilla-nss-certdata.txt`, avoiding target-side bootstrap TLS.
- Twenty-six focused D34 checks passed; shell syntax, Python compilation, and `git diff --check` passed. Package test suites and checksum calculations were skipped per the established user preference.

## Limits

This stack is installed only in the D34 candidate. The HDD `/mnt/lfs` rootfs and live ISO were not changed. The candidate still lacks resolver configuration, so name resolution in the target is unverified. M06 network integration and M09 rootfs/ISO lineage acceptance remain open.
