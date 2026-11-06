# D34 BLFS network stack replay — 30 September 2026

## Scope

Four network prerequisites were replayed in order on private NVMe Btrfs D34 snapshots: libunistring, libidn2, libpsl, and cURL. The active HDD `/mnt/lfs` rootfs and existing ISO were not modified. Each successful run has a Btrfs send delta, install event log, and durable ownership ledger. The user requested no source checksum calculations; package checksums and upstream package test suites were skipped.

## Successful replay sequence

| Package | Version | Run | Events | Send bytes |
| --- | --- | --- | ---: | ---: |
| libunistring | 1.3 | `libunistring-20260930T073353Z-ef19d6b5` | 32,392 | 55,992,671 |
| libidn2 | 2.3.8 | `libidn2-20260930T073641Z-8f30579c` | 15,535 | 19,493,931 |
| libpsl | 0.21.5 | `libpsl-20260930T073920Z-f1ecb93a` | 18,135 | 45,385,019 |
| cURL | 8.15.0 | `curl-20260930T074035Z-8d2128d8` | 74,691 | 53,671,273 |

Retained source archives were used: GNU libunistring and libidn2, the libpsl GitHub release, and the cURL GitHub release. cURL was configured for OpenSSL 3.5.2, libpsl, and CA path `/etc/ssl/certs`. Its `curl --version`, `curl-config`, `pkg-config`, dynamic-link, and installed-path checks passed.

## Ownership evidence

The cURL output snapshot's ledger is `COMPLETE`: all 79 official LFS Chapter 8 packages remain ordered and complete, with 15 separately declared BLFS supplemental runs, 4,850,424 path events, and 56,940 final system-path owners. A root-level check found every final path assigned to these packages (libunistring 53, libidn2 74, libpsl 9, cURL 2,209) in the read-only snapshot. The network executables, libraries, headers, and pkg-config metadata are present.

The runner/reconciler now require the dependency order `libunistring → libidn2 → libpsl → cURL`. Builders use the shared D34 mount-identity and writer-lock guard. Twenty-five focused D34 reconciliation, preflight, and builder-wiring checks passed; `bash -n`, Python compilation, and `git diff --check` passed.

## Failed attempts retained and corrections

- `libunistring-20260930T073309Z-699f83b0` stopped because the legacy HDD-only `$DATA/lfs` check fails in the private D34 namespace. The builder now validates the D34 target through the shared guard.
- `libidn2-20260930T073542Z-d8a62bd6` stopped because libunistring does not provide a pkg-config file. Its prerequisite check now validates the installed header, shared-library link, and 1.3 version macro.
- `curl-20260930T073955Z-a5fc320a` stopped because `openssl version` includes a build date after the version. The builder now validates the `OpenSSL 3.5.2` prefix.

All failures occurred before package build/install and are preserved in the replay directory. Each corrected replay passed.

## Limits

`/etc/ssl/certs` exists in the output snapshot but contains no certificates; `/etc/pki/tls/certs` is absent. No TLS network request was made, so certificate trust is not verified and M06 certificate infrastructure remains open. The cURL library and client are installed in the D34 candidate only; the active desktop rootfs and live ISO were not rebuilt from this candidate.
