# 10 October 2026 — interrupted GCC suite and scoped tester runtime

Run `691e0e2baea5796a181d934fb1bfe80d`, launched after `20cec85`, completed GCC compilation, including the previously failing m32 target libraries, and entered the unchanged tester suite after 26 package installations. The host subsequently rebooted. On recovery there was no live controller/QEMU, guest SSH was unavailable, and the run had no outcome. The exact shutdown cause is unknown; an old journal ends near a KDE logout prompt, which does not establish the cause. The interrupted run is not accepted or automatically replayed.

Both closed current qcow2 images passed read-only `qemu-img check --output=json` with zero check errors. `guestfish --ro` with `mount-ro /dev/sda /` recovered GCC metadata and test logs from the closed LFS image without booting or writing it. Recovery root: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/691e0e2baea5796a181d934fb1bfe80d/closed-guest-recovery-20261010/`.

| Recovered section | PASS | FAIL | XFAIL | UNRESOLVED | UNSUPPORTED | Completion |
|---|---:|---:|---:|---:|---:|---|
| gcc C | 204164 | 1909 | 1454 | 154 | 3846 | C section summary present; failed |
| g++ | 86133 | 3977 | 576 | 28 | 859 | Interrupted, no final summary |

No libstdc++ test outcome, GCC staged/installed PASS receipt, or complete Base outcome exists. These counts are recovered test records, not a complete GCC result.

The preserved host telemetry contains 1128 valid samples with zero recorded errors/kernel faults and a peak CPU temperature of 62.875°C, followed by a 987-byte NUL line. The original is preserved byte-for-byte. It does not provide a complete final monitor result. Prior boot ID `a91cb75f-4b89-4695-88ef-b845f2c04957` differs from recovery boot `de524c10-9977-4d5f-a6b7-ee93f226e133`.

Two concrete software issues were observed before interruption and confirmed in the recovered logs:

- Target test executables were compiled against LFS Glibc 2.42, but their default interpreter loaded Builder's older libc, which lacks `GLIBC_2.38`. This also affected newly built libstdc++/sanitizer execution and cascaded into gcov/profile failures. The build sysroot correction itself allowed GCC's m32 compilation to finish; execution still needed target runtime isolation.
- 32 native `gcc.dg/plugin` helper compilations used Builder `g++` without the staged GMP include path. GCC `system.h` could not find `gmp.h`. The upstream plugin helper takes this path from `GMPINC`, separate from ordinary target `CPPFLAGS`.

The runner now adapts only the exact pinned tester command. It temporarily edits the generated `build/gcc/specs` glibc loader operands in the existing `*link` conditions: m64 uses `/srv/lfs/usr/lib/ld-linux-x86-64.so.2` and its RUNPATH; m32 uses `/srv/lfs/usr/lib32/ld-linux.so.2` and its RUNPATH. Shared/static/static-PIE conditions, x32/other libc branches, every other specs section, compiler options and all test cases remain intact. Native Builder compiler tools retain their dependency environment. GCC documents specs and conditional linker argument processing in its [upstream specs reference](https://gcc.gnu.org/onlinedocs/gccint/Spec-Files.html).

For native plugin helpers, the adapter appends `set GMPINC "-I/srv/lfs/stage/base-gmp/usr/include"` in `build/gcc/site.exp`'s supported user override section. Actual checksum-verified GCC source preserves that section when generating site.exp and copies it to the test directories. `plugin-support.exp` consumes GMPINC only in its native plugin helper include list. The source hook and native `PLUGINCC=g++` are pinned; no target compiler or global system header path is changed.

Before adaptation the runner validates the exact recipe shell command/native environment, source hooks, original generated metadata, canonical paths, staged GMP header and both loader/libc ELF ABIs (ELF64/x86-64 and ELF32/i386). Unknown metadata, changed commands, aliases, missing payloads or wrong ABIs fail closed. Original specs SHA-256 `8b11ad11ba0940b4c607e18d902543471dbb935be04588e1d96c9bd7591c0df7`; site.exp SHA-256 `c6a13c29ec388d34a0b26670131ccc55b85fe80231e0eedc014cb4e095abed7e`; actual plugin-support.exp SHA-256 `6cc57b8b8057fcde7566bc42f17eb2e18a0518e28588bc522a5c1108cbc843ad`.

A coordinator-owned 0600 backup marker is fsynced before metadata edits. Normal completion, test failure, SIGTERM and SIGINT restore both originals byte-exact before staging. Metadata drift or changed inode/ownership fails closed. SIGKILL/power loss cannot run restoration; the persistent marker blocks later commands in that GCC build tree. A fresh accepted-parent run gets a new build tree. No staging proceeds from an interrupted adapter.

The pinned recipe, four jobs, complete tester command, ownership checks and strict expected-failure policy are unchanged. The existing exact known-failure allowance has not been broadened. Accepted checkpoints, current interrupted images and later milestones are preserved.

Validation:

- 82 focused guest-runner tests PASS, including actual recovered metadata, command/environment drift, ABI/alias rejection, byte-exact success/failure/signal restoration, changed-inode protection and a real subprocess SIGKILL leaving a durable staging block.
- Full host/synthetic suite: 403 tests, 2 skipped, PASS in 104.988 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-gcc-tester-runtime-20261010.log`, SHA-256 `837dfbbec18cb5dd591ecace9b00c790802baf3b748cd008ebb1b6fd42dd04cb`.
- An unprivileged host probe used the integrated adapter, checksum-verified actual GCC 15.2 source rules and `20221006-1.c`, exported actual Glibc 2.42 bytes, and the exported GMP header (archive hash bound to its built receipt). All eight m64/m32 O0/O1/O2/O3 compile/run cases passed with the expected interpreter/RUNPATH. Link dry-runs preserved shared/static/static-PIE branches. Tcl evaluated the site override and native g++ accepted the actual GMP header. The adapter restored the original metadata byte-exact; its temporary tree was removed. This tiny probe does not establish full guest GCC or plugin-suite acceptance. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-tester-adapter-probe-20261010.json`, SHA-256 `2a7c55e89f5cdb23c4b41a76d3c7188b890075d487b2f71b3dfb766a095bfc34`.
- The earlier standalone runtime probe also passed eight variants and reproduced optimized m64 `GLIBC_2.38` failures with the old Builder loader. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-target-runtime-specs-probe-20261008.json`, SHA-256 `1ccd707569308140366ee4381dff12796146afc2a5d0900dbe79d293dc6b8264`. It was not an integrated adapter test.
- Runner SHA-256 `0a23a98747ffe066287f4dca76314effa8a1392c853eea002e323c67991bdd41`. Canonical inputs remain `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`; no independent agent review was performed.

Recovery and observation receipts:

- `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-interrupted-run-recovery-20261010.json` SHA-256 `eb022b964796b74f5d364d577dafcbfc77846bf3c326fad43c96ebb755cb5a07`, records all recovered file hashes, suite counts, raw telemetry hash/invalid line and closed qcow2 checks.
- `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-target-runtime-observation-691e0e2baea5796a181d934fb1bfe80d.json`, SHA-256 `112f80e4433a561eb87c50dd5c95854a6bd43d02a0f0cfaf9bf4fdc0d6c159e9`.
- `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/gcc-native-plugin-observation-691e0e2baea5796a181d934fb1bfe80d.json`, SHA-256 `f8c0a0ce2aafa7bad104a0786d52f31f62bc674658fe575de52ec740aa96d935`.

Previously authorized cleanup during the Oct8 run removed only the two obsolete failed `6e02ccfa24eac8c841564b85e7b3a9f9` leaf images after two scans of 91 qcow2 metadata records, no-open-descriptor checks, closed-image checks and independent hashes matching their preservation manifest. Logs/manifest remain. It reclaimed 7,626,465,280 allocated bytes; accepted checkpoints and newer failed images were protected. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-failure-6e02ccfa24eac8c841564b85e7b3a9f9-20261008.json`, SHA-256 `e4b29295d3040979a2d5ca9b2b5c9b1ce0a28ae81e11ffc6b62ea028b71ad6fb`.

On Oct10, the obsolete failed MPFR run `f6c8fcb01988262f6a7c55d33ac24001` leaf pair in `preserved-overlays-1791437649215371568` was also removed under the existing cleanup authorization. Read-only guest inspection confirmed the run identity. All exported artifact hashes were rechecked against its failed outcome and remain preserved. Two quiescent scans of 89 managed qcow2 metadata records found no backing references; accessible process descriptors, closed-image checks, complete image SHA-256 and unchanged stat identities were checked before deleting exactly the two leaf files. Reclaimed allocated bytes: 8,455,004,160. The current interrupted images, later Libxcrypt milestone and all accepted checkpoints remain intact. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-mpfr-overlay-20261010.json`, SHA-256 `8c0ba84eb66903a63f674922b57f943b74dfb5181f7a3cb025d3e9c7742957d9`. Afterwards root/SSD/HDD had 18.63%/25.35%/16.73% free; the mandatory 15% floor still applies throughout the new build.

The documentation checker reports the same 31 historical findings (19 commit references, 10 decision references, one stale term and one broken link); this report is not flagged. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-gcc-tester-runtime-20261010.log`. This is not clean documentation acceptance. Python compilation and `git diff --check` PASS.

Next: push the verified adapter and evidence, then launch one fresh persistent Base stage from the accepted toolchain parent. Actual full GCC/Coreutils/Base acceptance remains unproven. Kernel, BLFS, Plasma/GL, ISO and complete fresh repeat-byte acceptance remain open; prior Glibc package-byte repetition does not satisfy those gates.
