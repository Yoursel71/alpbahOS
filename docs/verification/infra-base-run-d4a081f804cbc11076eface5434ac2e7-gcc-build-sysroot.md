# 8 October 2026 — actual Libxcrypt success and GCC target build sysroot

Run `d4a081f804cbc11076eface5434ac2e7`, launched after `63b9738`, installed 26 packages. The Man-pages source-path correction passed in the actual isolated QEMU/KVM Builder: both crypt pages are absent from its manifest and present in Libxcrypt. Libxcrypt native tests report 32 PASS, 11 SKIP, 0 FAIL; native/m32 staging and ownership-checked installation passed. Independently rehashed guest archive/manifest match the installed PASS receipt:

- Archive `903486b6c2a3e3fafe361d5dc01827ceffd1c0fc138d35df9e4c4b7d50611adb`.
- Manifest `cf6480f4fbf3deb717e2cc13dbed09b7c7651674fb8b9a246a2a6f6beadb2466`.
- Read-only observation `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/libxcrypt-ownership-guest-observation-d4a081f804cbc11076eface5434ac2e7.json`, SHA-256 `0624cd04f4d38d4af0b026bd99808f1c3bb00abef77302fc6c43f179cf9fde18`. Captured during the active run; tracked documentation was updated only after the controller exited.

The run then stopped at GCC's first target m32 Libgcc compilation, before GCC tests or staging:

```text
/usr/include/stdio.h:27:10: fatal error: bits/libc-header-start.h: No such file or directory
make[4]: *** [../../../../libgcc/shared-object.mk:14: generic-morestack.o] Error 1
```

The compiler used Builder system headers instead of the already installed LFS target headers. The native Builder has no matching m32 system-header layout. This is an isolated target-path configuration failure; the evidence does not demonstrate compiler or overclock instability.

The guest adapter now adds exactly `--with-sysroot=/` and `--with-build-sysroot=/srv/lfs` to the pinned GCC configure command. GCC's upstream build-sysroot option routes target headers, startup objects and libraries through LFS while the compiler's native build tools retain their Builder environment. The installed compiler's system root remains `/`. The actual GCC 15.2 Makefile uses `SYSROOT_CFLAGS_FOR_TARGET` in `TEST_ALWAYS_FLAGS`, so target test compilations also receive the build sysroot. See [upstream configure options](https://gcc.gnu.org/install/configure.html).

Before adaptation, the runner validates the exact configure command, canonical source/build/sysroot directories, required Glibc headers/startup objects, m64 ELF64/x86-64 and m32 ELF32/i386 libc payloads, and the supported source configure/test rules. Unknown compiler overrides, changed configure options, missing or aliased payloads, incorrect ABIs and source-rule drift fail closed. The recipe, input digest, four build jobs, full tester command and expected-failure policy are unchanged. No accepted checkpoint or installed target file was edited. Full new GCC build/test/install and Coreutils/Base acceptance remain unproven.

Validation:

- 72 focused guest-runner tests PASS. The new cases compose the actual recipe, preserve all existing compiler/multilib options, exercise GNU make's test-flag rule, leave test/staging commands unchanged and reject command, header, ABI and source-metadata drift.
- Full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v`: 393 tests, 2 skipped, PASS in 92.417 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-gcc-sysroot-20261008.log`, SHA-256 `8a90e85a78f4c143ecccead7d63a7ebb91465769821bb14766eb364d9d1a8c31`.
- An unprivileged probe used checksum-verified GCC 15.2 source metadata and the actual exported Glibc archive's headers, m64/m32 libraries and startup objects. The adapter passed, and the actual source Makefile rule generated the expected test sysroot flag. It did not build a compiler or install anything on the host root; its temporary tree was removed. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-actual-source-sysroot-probe-20261008.json`, SHA-256 `b0a78d9a06e1122c58f78dee814ebcc3a67ccc9f12f1656b07666f618a50ef21`. Source archive SHA-256 `438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e`.
- Runner SHA-256 `3bad7a7df51701ad1c77fa469b90f3fd39911a373c404e43b0d6ab1de3d9b88f`; canonical input remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`. Space guard and `git diff --check` PASS. No independent agent review was performed.

The controller closed the failed guest cleanly. Both current failed qcow2 images passed `qemu-img check --output=json` with zero check errors. All 360 exported artifact hashes were recomputed and match the failed outcome; all 26 installed receipts report PASS. Evidence root `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/d4a081f804cbc11076eface5434ac2e7/`:

- `base.log`: `463dfad142c41b2b32d8942cd9fb1bfd4e2925dcce5c377db8ee14de3f039cf4`.
- `guest-base-partial/gcc/base-gcc.log`: `480521e40852adf234fd1caf6566077d426c549b6d57fd93330928be640682a1`.
- `base.host.jsonl`: `216cc1fabcfadd7bcf3f0b3bb0cf2c5c6861915bd2dc321607b5c4ad2e33c69e`; 411 samples, zero errors/kernel faults, maximum CPU temperature 63°C. Minimum free bytes: root 50,198,646,784; SSD 26,230,763,520; HDD/data 74,886,012,928. Every disk stayed above 15% free; throttle counters were unavailable.
- Evidence verification receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-failed-run-evidence-d4a081f804cbc11076eface5434ac2e7.json`, SHA-256 `1de5be2c80d5809c85fc2978b1a8dc9d8b5bfa88b78672f3c2acd4c7d691ec81`.

Glibc's exported archive and manifest were rehashed again: `7815dcff6630a5ab34debc6b8c9c62114b1653781f0dc68457388301ce6a7b98` and `21cc505e0d8694e4e73a1469d93828116268166681f9edd753871a8dcdd112eb`, matching previous fresh attempts. This proves Glibc package-byte repetition only. The run has no complete Base acceptance or checkpoint; kernel, BLFS, Plasma/GL, ISO and full repeat-byte acceptance remain open.

The obsolete failed `242ccde0598d732459f7f88158dc2e92` leaf overlay pair in `preserved-overlays-1791458649771159465` was removed under the user's unused-artifact cleanup authorization. After the full suite completed, a quiescent scan checked 91 managed qcow2 metadata records and found no backing reference to either leaf. Both checks, hashes and file stat identities were recorded before removal and rechecked. Reclaimed allocated bytes: 7,281,713,152. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-overlay-242ccde0598d732459f7f88158dc2e92-20261008.json`, SHA-256 `7c212a0aeb3c07465c37fb1cc17dbc818d2558381259c5ecb7a259d37e51f012`. Current failed images and accepted checkpoints remain intact.

The documentation checker still reports the same 31 historical findings (19 commit references, 10 decision references, one stale term and one broken link); this new report is not flagged. This is not clean documentation acceptance. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-gcc-sysroot-20261008.log`.

Next: commit/push the verified GCC build-sysroot correction and evidence, then launch one fresh persistent Base stage from the accepted toolchain checkpoint. Preserve the current failed images, accepted checkpoints, important milestones, desktop/user applications and CPU settings.
