# 8 October 2026 — ACL compiler adapter composition and Glibc byte repetition

Base run `50b177e8cda3242c0c0b0e2f5a680c05` installed 22 packages. ACL's native m64 configure, build and tests passed; its test summary reports 15 total, 9 PASS, 4 SKIP, 2 XFAIL, 0 FAIL and 0 XPASS. Native staging/install and distclean completed, then the guest runner rejected the m32 configure before executing it:

```text
RuntimeError: ACL dependency adapter received an unexpected compiler
```

The earlier `prepare_m32_kernel_headers` adapter intentionally replaces the recipe's `CC=gcc -m32` with `CC=/srv/lfs/tools/bin/x86_64-lfs-linux-gnu-gcc -m32`. The new ACL dependency adapter in `724afff` accepted only the original command and the host GCC value in subsequent `config.status`. Its isolated tests missed this preceding adapter. This is a composition bug in the runner, not an ACL source/test failure or demonstrated CPU instability.

The ACL ABI selector now also accepts exactly the existing pinned `M32_C_COMPILER` command and the same value in generated compiler metadata. Unknown paths, additional compiler options and aliased/missing metadata remain rejected. The accepted m32 compiler is not replaced with the Builder compiler. A regression test uses the actual pinned ACL recipe command, runs the preceding m32 adapter first, then runs the staged dependency adapter and checks the generated-compiler make path and Attr m32 bytes. It also rejects an altered compiler prefix and unreviewed include options. No recipe, source/toolchain input, test suite or acceptance gate changed. Full ACL/Coreutils/GCC success still needs the next actual guest run.

Glibc installed PASS in 1,868.872 seconds. The current guest package archive and manifest were hashed read-only before the run ended, and both hashes matched the prior `df7d37687c6345496ff969e338e840a4` actual host files. The exported current files were independently hashed again after shutdown and agree:

- Archive SHA-256 `7815dcff6630a5ab34debc6b8c9c62114b1653781f0dc68457388301ce6a7b98`.
- Manifest SHA-256 `21cc505e0d8694e4e73a1469d93828116268166681f9edd753871a8dcdd112eb`.
- Observation `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/glibc-package-byte-repeat-50b177e8cda3242c0c0b0e2f5a680c05.json`, SHA-256 `5acfa7ba6a12f9f08205b0cb2af50b72337471bbc522405c314a2ab617fd9567`.

This proves Glibc package-byte repetition across two fresh Base attempts after the deterministic index fix. It does not prove complete Base/ISO repeat-byte acceptance, boot or a finished distribution.

The controller closed the VM cleanly; both current active qcow2 checks passed. Raw evidence is under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/50b177e8cda3242c0c0b0e2f5a680c05/`:

- `base.log`: SHA-256 `096b6b1e84399cc3c87ed7e76664b3c880e990ae0483fe5264d6701d5a1773f5`.
- `guest-base-partial/acl/base-acl.log`: SHA-256 `5eff8ce6bb289c6a222cd2fb04c1fb2216285515614e3d123a39927a24699de0`.
- `base.host.jsonl`: SHA-256 `d5057606931064cc871b090fcc48f5ab13741383ac1aba87f43806e8936254a4`; 341 samples, zero errors/kernel faults, temperature 33.5–62.5°C. Minimum free bytes: root 50,070,106,112; SSD 27,830,906,880; HDD/data 75,296,198,656. All volumes remained above 15% free.

Validation: 56 focused adapter tests PASS. Full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` passed 377 tests with 2 skipped in 92.176 seconds. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-acl-m32-adapter-20261008.log`, SHA-256 `16821d471c5a079b72ff0d02ad3a6dd4034678a2f08d79e8c6120d2968015275`. Runner SHA-256 `7a98552de919359433970438fd9357e1d2390f30c19bc98137eb225384ece6c9`. Input digest remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`; space guard and `git diff --check` PASS. No independent agent review was performed.

Under the user's unused-artifact cleanup authorization, the previous unreferenced failed `df7d37687c6345496ff969e338e840a4` overlay pair at `preserved-overlays-1791446202013480404` was removed before relaunch. All 73 managed qcow2 metadata records were checked; no backing reference targeted those leaf overlays. Both images passed qcow2 checks; hashes and exact name/device/inode/size/mtime evidence were recorded before removal. Allocated bytes reclaimed: 7,199,006,720; SSD now about 33 GiB free. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-overlay-df7d37687c6345496ff969e338e840a4-20261008.json`, SHA-256 `aba054d94eda6e4cfaf9d793fd659a0da6014160f3b3c5c7c56c27a2d49e63de`. Current failed images and accepted checkpoints remain intact.

The documentation checker reports the same 31 historical findings; the new report is not flagged. This is not clean documentation acceptance. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-acl-m32-20261008.log`.

Next: commit/push the checked change and start a fresh persistent Base run from the accepted toolchain. The current failed images, accepted checkpoints and important milestones are preserved. No user applications or CPU settings were changed.
