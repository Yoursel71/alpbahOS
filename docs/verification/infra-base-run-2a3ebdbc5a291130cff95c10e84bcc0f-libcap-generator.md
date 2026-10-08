# 8 October 2026 — Libcap native header generator and actual ACL multilib install

Base run `2a3ebdbc5a291130cff95c10e84bcc0f`, launched after `38813e3`, installed 23 packages including ACL. ACL's native tests report 15 total, 9 PASS, 4 SKIP, 2 XFAIL and 0 FAIL. The m32 configure/build/staging completed with the pinned compiler and ABI-matched Attr view; `acl.installed.json` reports PASS. The exported package contains `libacl.so.1.1.2302` as ELF64/x86-64 under `/usr/lib` and ELF32/i386 under `/usr/lib32`. This confirms the preceding ACL adapter composition fix in the actual guest. Coreutils and GCC have not yet been reached.

Libcap's native build, tests and staging completed. After distclean, its m32 make command failed when executing its freshly compiled `_makenames` header generator:

```text
./_makenames > cap_names.h
/bin/sh: line 1: ./_makenames: cannot execute: required file not found
```

The pinned Libcap 2.76 `Make.Rules` sets `BUILD_CC ?= $(CC)`, and the exact `_makenames` rule uses `$(BUILD_CC)`. The earlier adapter intentionally selects the isolated LFS compiler for target m32 code. Consequently the build-time helper also used that compiler and its target interpreter, which is unavailable in the unchrooted Builder. This is a build/target ABI separation error, not a demonstrated CPU instability or source checksum fault.

The guest adapter now supplies the upstream-supported `BUILD_CC=/usr/bin/gcc` only for the two exact pinned Libcap m32 make invocations (build and library staging). The target `CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32 -march=i686`, job limit, install destination and test policy remain unchanged. Canonical source metadata, the BUILD_CC default and the generator rule are checked; unknown compiler/options, command drift and aliased metadata fail closed. Native tests, other packages and accepted stage bytes are unaffected. No recipe/source/toolchain input changed; the runner remains separately SHA-bound. Full new Libcap guest success still requires the fresh run.

Validation:

- 61 focused guest-runner tests PASS, including composition with the actual recipe, GNU Make evaluation of separate helper/target compilers, staging preservation and rejection tests.
- Complete `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: 382 tests, 2 skipped, PASS in 90.652 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-libcap-generator-20261008.log`, SHA-256 `300973a53ec6ec2014fa7c88e36b77a22f6ade9ef889b48a4709c59360d6c1ed`.
- An unprivileged, temporary-copy probe of the actual checksum-verified source compiled only `_makenames` with the composed adapter command. The helper is ELF64/x86-64 and executed successfully, producing 1,682 header bytes, SHA-256 `79dc8364f4268ac14aa2be9373d95024068515d23380a59b62d9f9d37b4eb18d`. The temporary tree was removed. No target library/root build occurred on the host. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/libcap-native-generator-probe-20261008.json`, SHA-256 `32b45acc306ae4fa409ebf36a599031116fb6bda1b4fbee4a717bfb9d3f88fe3`.
- Runner SHA-256 `cbdc9b37785e7a6bdbea984bff13de57082a91ad9e97559ae51aae8d6054d829`; input digest remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. Space guard and `git diff --check` PASS. No independent agent review was performed.

The controller closed the VM cleanly; both current failed qcow2 images pass `qemu-img check` and remain preserved. Raw evidence root: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/2a3ebdbc5a291130cff95c10e84bcc0f/`:

- `base.log`: SHA-256 `801f931fd0ab05c38081f3e2e647428a00a7fbb1c22134c55a6fa40cbb98d478`.
- `guest-base-partial/libcap/base-libcap.log`: SHA-256 `04aed077998881f8593214f315743370a3160fbbd4da7a2891086bd84f0400fb`.
- `guest-base-partial/acl/base-acl.log`: SHA-256 `3f1e8a8bda4e94dc79dbcb735266801821d94a54df4bec7aaa6d6223092caf3e`.
- `guest-base-partial/acl/acl.installed.json`: SHA-256 `317b50e8062f6e6992609d9b835a732bbddbfdfb3847f6543cd5d1a93aa9a54c`.
- `base.host.jsonl`: SHA-256 `017364b5d46d9f7e70f06e5063f8f9fda56a5dd454cc26f6efe70e4c50cbe461`; 345 samples, zero errors/kernel faults, maximum CPU temperature 62.5°C. Minimum free bytes: root 50,069,037,056; SSD 27,347,873,792; HDD/data 75,160,317,952. Every disk remained above 15% free. Throttle counters were unavailable; no throttle-counter pass is claimed.

Glibc installed in 1,874.817 seconds. Independently hashing this run's exported archive and manifest again gives `7815dcff6630a5ab34debc6b8c9c62114b1653781f0dc68457388301ce6a7b98` and `21cc505e0d8694e4e73a1469d93828116268166681f9edd753871a8dcdd112eb`, matching the two previous fresh attempts. This is Glibc package-byte repetition only, not complete Base/ISO acceptance. The run has no Base acceptance or checkpoint.

Under the user's unused-artifact cleanup authorization, the previous failed run `50b177e8cda3242c0c0b0e2f5a680c05` leaf overlay pair `preserved-overlays-1791450203170731764` was removed after scanning 91 managed qcow2 metadata records and finding no backing references to it. Both images passed checks; hashes and device/inode/size/mtime evidence were recorded and rechecked before removal. Reclaimed allocated bytes: 7,915,511,808. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-overlay-50b177e8cda3242c0c0b0e2f5a680c05-20261008.json`, SHA-256 `a535f3aa33e05c57d505d68599aaa72e286614145a513c3c74aa56a47c4e9ef8`. SSD free is now about 33 GiB. Current failed overlays, accepted checkpoints and important milestone ISOs remain protected.

The documentation checker still reports 31 historical findings (19 commit references, 10 decision references, one stale term and one broken link); this new report is not flagged. This is not clean documentation acceptance. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-libcap-generator-20261008.log`.

Next: commit/push this checked correction and evidence, then launch one fresh persistent Base run from the accepted toolchain checkpoint. Desktop/user applications and CPU settings are unchanged; full Base and later stages remain open.
