# 8 October 2026 — ACL staged Attr dependency and successful MPC fix

Base run `df7d37687c6345496ff969e338e840a4` installed 22 packages, including MPFR, MPC and Attr. MPC's compile, tests and install passed: the shared-only Libtool dependency view introduced in `bc4401f` worked in the real guest. MPFR now records `dependency_libs=' -lgmp'`, MPC records `dependency_libs=' -lmpfr -lgmp -lm'`; neither exports scratch/stage library paths into these sidecars. GCC has not been reached.

The run failed during ACL's first configure:

```text
checking for attr/error_context.h... no
FATAL ERROR: attr/error_context.h does not exist.
```

Attr's accepted stage contains the missing header and both `usr/lib/libattr.so` and `usr/lib32/libattr.so`. ACL compiles outside the target chroot and searched the Builder's headers. This is a staged dependency visibility error; the controller stopped the VM cleanly. Both closed active qcow2 images passed `qemu-img check`. The failed current images and accepted checkpoints remain intact. There is no complete Base acceptance/checkpoint.

The guest adapter is now named `native_staged_dependency_environment` and gives ACL only Attr's staged headers and shared-only library view. Initial native configure selects `usr/lib`; the pinned `CC=gcc -m32` configure selects `usr/lib32`. Subsequent make/test/install/distclean commands select the ABI from the bounded, canonical generated `config.status` compiler value. Unknown compilers, missing/aliased metadata, absent ABI libraries and escaping nested header paths are rejected. The two library views remain separate, and accepted stage bytes are unchanged.

Coreutils also explicitly requires Attr and ACL in its pinned recipe. Its native commands now use those same isolated dependency views, preserving ACL feature visibility rather than depending on Builder development packages. Its unchanged book root checks and tester checks keep the dependency runtime paths: the nested `runuser` would otherwise strip `LD_LIBRARY_PATH`, so the exact pinned tester env command explicitly restores only the two isolated views. An unexpected root/tester command is rejected. No test, feature requirement or acceptance policy is removed. Real ACL/Coreutils guest success remains to be verified in the next run.

Glibc's six `ranlib -D` operations ran in the guest before manifest capture, and installation passed in 1,861.923 seconds. Its archive SHA-256 is `7815dcff6630a5ab34debc6b8c9c62114b1653781f0dc68457388301ce6a7b98`; manifest `21cc505e0d8694e4e73a1469d93828116268166681f9edd753871a8dcdd112eb`. A read-only manifest comparison against the prior run found the same 1,881 paths and exactly six changed hashes. Those six hashes equal the prior actual archives' normalized temporary-copy hashes; the other 1,875 complete entries and all non-hash fields are identical. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/glibc-index-adapter-guest-observation-df7d37687c6345496ff969e338e840a4.json`, SHA-256 `9d34f7707e0859055cea9810e10763aa45a7ef5a51c11e24e6a644edea5b045e`. This verifies the guest adapter's observed effect, not full raw-byte repeat-build acceptance.

MPC archive SHA-256 `aee7f060f8432e29222696a987d5942bbc5f6d23a37aef76dcd9c67fb9691143`, manifest `24c56db4f62f8e73afd8bb83fc02118885374565069428f01943cea65b317f3b`. Raw evidence under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/df7d37687c6345496ff969e338e840a4/`:

- `guest-base-partial/acl/base-acl.log`: SHA-256 `c2bdf630048f97a11b35cee1a71e19eaadba0ca2032e3674fc5b0537f2a8d0ed`.
- `guest-base-partial/mpc/mpc.installed.json`: PASS, SHA-256 `786f9d40c44d18d1a9ba2248195f1542ba171baff1d520c4776d31c40b06b28f`.
- `base.host.jsonl`: SHA-256 `08b6c787428522917e5f8d0510a37d011bd42ad37bc8b5d864c7d50142253bb9`; 340 samples, zero errors/kernel faults, temperatures 38.125–62.25°C. Minimum free bytes root 50,073,055,232; SSD 27,883,413,504; HDD/data 75,432,099,840. Every disk remained above 15% free.

Under the user's unused-artifact cleanup authorization, the obsolete failed `0b2b1a2bd079706ba6bb99971c84d907` overlay pair at `preserved-overlays-1791441977976150216` was removed before the next launch. All 78 managed qcow2 metadata records were checked for references to those leaf overlays; none referenced them. Both passed qcow2 checks, exact names/device/inode/size/mtime and SHA-256 evidence were recorded before removal. The latest failed current pair and all milestone/accepted checkpoints are preserved. Allocated space reclaimed: 7,903,977,472 bytes; SSD free rose to about 33.6 GiB. Receipt `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/cleanup-unused-overlay-0b2b1a2bd079706ba6bb99971c84d907-20261008.json`, SHA-256 `97d7af42bba357f515373b5b43f07ea7e3241ecdb89b7bb280e093f2a2ba2830`.

Validation: 55 focused adapter tests PASS. Full `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests -v` passed 376 tests with 2 skipped in 90.135 seconds. Full log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-acl-staged-attr-final-20261008.log`, SHA-256 `97b465cdc2739be6b5fd75852b4d1435b1834e0c52b38fc3d8a54c9d7fb9eddf`. Runner SHA-256 `55546ac2a7e48eea475b02ec2d4813c2e2604cb63b9eefadc281c007e4f238af`. Input digest remains `c76a1c737693aab8a4380a395a9515da8d86a7f641099c6f9e5ba4166e4f7306`; runtime space guard and `git diff --check` passed. No independent agent review was performed.

The documentation checker still reports the same 31 historical findings; the new report was not flagged. This is not clean documentation acceptance. Log `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-doc-check-acl-attr-20261008.log`.

Next: commit/push the verified change, then launch a fresh persistent Base run from accepted toolchain. Preserve the healthy run, continue the authorized pipeline only after actual Base acceptance, and complete required repeat-byte verification. User applications/CPU settings were not changed.
