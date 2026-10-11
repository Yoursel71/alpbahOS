# 11 October 2026 — second interrupted Base run

Fresh run `fa5accc90d3627ccbcd6ea32323be518` was launched from the accepted toolchain parent by `alpbahos-infra-base-20261010T102048Z-49729.service` after pushed commit `f8f64ce`. Recovery found no live alpbahOS service, controller or production QEMU process. The run has `run.json` and `started.json`, but no outcome. Its host boot `de524c10-9977-4d5f-a6b7-ee93f226e133` differs from current boot `96d39e6d-37a7-4303-acb4-61235026c4cc`. No completed software failure or acceptance is inferred.

Host telemetry has 131 valid JSON samples, no malformed lines, zero recorded monitor errors/kernel faults, peak 65.125°C, and last completion 2026-10-10 10:46:29.803685 UTC. Original SHA-256: `512a78faca6490595d8e4278da30a3dbadb2747765be86a5dfa43342d6692b67`. This is incomplete monitoring.

The run-boot kernel journal contains `clocksource: Watchdog remote CPU 12 read timed out` at 10:32:34 UTC. This warning is outside the monitor's recorded fault pattern; zero recorded faults does not imply no relevant warning. The available journal tail has no orderly host shutdown sequence or terminal controller result. Subsequent boots have inconsistent initial wall clocks; boot ordering/IDs are more reliable than inferred reset times. Current journald reports an unclean/corrupt journal replaced on boot. Read-only privileged listings found empty `/sys/fs/pstore` and `/var/lib/systemd/pstore`. None of these records proves a hardware, OC or power cause. Exact interruption cause remains unknown.

Both closed images passed read-only `qemu-img check --output=json`, exit 0, zero check errors. Full hashes were recorded with unchanged device/inode/size/mtime/ctime across hashing:

| Protected current image | SHA-256 |
|---|---|
| `builder-active.qcow2` | `5a4985171c53eb27c7152ce1dbdfc6164ec18ee4a59507afb5f0d98fe2fac23c` |
| `lfs-active.qcow2` | `28e5bd188cfa18374ea38e61d3cfe0323c75ec798ed6cedfdbd8ed6fc4ebca9c` |

`guestfish --ro`, `mount-ro /dev/sda /` and `tar-out` recovered results without booting, repair or guest writes. Recovery directory: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/fa5accc90d3627ccbcd6ea32323be518/closed-guest-recovery-20261011/`. Guest result archive SHA-256: `5f765174997a5e10152ceef7b28919a804f492cfe41e05de44dbfe74ddaa45d5`.

Man-pages and Iana-etc have installed PASS receipts; their archives, manifests and indexes independently rehash to those receipts. Ncurses has a built receipt but no installed receipt. Glibc has a build-start record and incomplete native test log ending during `rt/tst-cputimer2`, with no terminal policy or installed receipt. Its 32,665,600-byte log has 509 trailing NUL bytes, preserved unchanged; SHA-256 `6b54d9864fe74583baa6c71610bfef0c6030ffba08d0865fe440c5a48d77f4aa`. GCC was not reached; no GCC runtime marker exists. The fresh guest has not proven the GCC adapter.

Recovery receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/base-interrupted-run-recovery-fa5accc-20261011.json`, SHA-256 `0daf9aaf2cef9c70324c1ca42ec0e89e30cbdbafda645423ab669dfc71dbf0fb`, binds 20 independently rehashed capture files, including journal/service/process evidence, image checks, host snapshot and guest observation. Partial receipts and logs are not Base acceptance; no outcome was manufactured.

Current read-only sampling has no monitor errors/faults, CPU about 38°C and available space root 18.81%, SSD 20.31%, HDD 16.72%, above the mandatory 15% floor. This snapshot does not prove long-load stability or post-run RPM acceptance. No images were deleted, checkpoints altered, desktop applications stopped or CPU/OC settings changed. Current images, the earlier interrupted `691e0e2baea5796a181d934fb1bfe80d` pair and the Libxcrypt milestone remain protected.

The existing user stability requirement prevents hiding repeated unexplained interruptions through recipe changes or repeated long builds. A clarification asks whether host reboots were intentional or spontaneous. Preserve evidence and defer the next long stage until trusted clarification or concrete diagnosis resolves this uncertainty. Keep the heartbeat active to rediscover live state and notify only for material changes; neither interrupted run may be replayed or accepted. Safe continuation requires one fresh accepted-parent stage with all strict tests and ownership checks. Full GCC/Coreutils/Base, kernel, BLFS, Plasma/GL, ISO and complete fresh repeat-byte acceptance remain open.

Only evidence/status documents changed. Production runner, recipes and failure policy remain at `f8f64ce`; no independent agent review or new production test run was performed.

Validation: all 20 receipt-bound capture hashes were independently rechecked, `git diff --check` passed, and canonical input digest remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. The docs checker reports the same 31 historical findings, with this report unflagged; log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-base-host-interruption-20261011.log`. This is not clean documentation acceptance. The host/synthetic suite was not repeated for document-only edits.
