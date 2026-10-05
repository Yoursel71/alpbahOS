# Base stage interruption: runuser SIGSEGV

Date: 2026-10-05
Run: `8f03e7cdddd7e537bd6ce4baf1ea9895`
Stage: LFS base package sequence, stopped during Expect source patching.

## Finding

The guest serial log records `runuser[2403863]` faulting at instruction pointer `0x2` on guest CPU 2 after 4584.616 seconds of uptime. The immediately preceding recorded operation in the Expect package log is:

`/usr/sbin/runuser -u lfs -- patch -Np1 -i /srv/lfs/sources/expect-5.45.4-gcc15-1.patch`

The stage is FAIL/incomplete. The guest controller did not accept the base stage, and no base checkpoint was created. Do not replay or resume this partial run.

## Diagnostics

- Host monitor recorded 452 samples; no reported `errors`, `kernel_faults`, or `mce` entries. CPU temperature range in those samples: 34.375–59.0 C. The monitor reports throttle counters unavailable, so this is not evidence that hardware is stable.
- Host kernel journal query for hardware/MCE, QEMU/KVM, and fault messages in the run window returned no matching entries.
- Builder guest's `/var/lib/systemd/coredump` was empty when inspected offline.
- `/etc/environment` and `/etc/profile` in the Builder image contain no `LD_LIBRARY_PATH`/`LD_PRELOAD` export. Code review did find a likely software cause: the Expect Tcl adapter added `/srv/lfs/usr/lib` to the process environment for every command in the Expect build directory, including the `runuser ... patch` command. That allowed Builder's privileged `runuser` executable to resolve libraries from the target LFS root before switching users. The adapter now removes that variable from `runuser`'s outer environment and adds it only to the inner `env` command. This explanation is plausible and test-covered, but an actual retry is still needed to confirm it.
- The failure overlays remain at `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/{builder-active.qcow2,lfs-active.qcow2}` with the accepted toolchain checkpoint as their backing images. `qemu-img info --backing-chain` reports `corrupt: false` for both chains.

## Evidence hashes

- Expect package command log: `13fa560e64e8e73e761201a7bbd2b241cfe400806c8933b2f28b9bb484c7bf76`
- Guest serial log: `98265d9f442055ac384a8d92ca4fc168f5adf28347978d6e4a93dd5a13854780`
- Host telemetry: `3e999ac2c6a9acb9de8fbe4191de135a5e81ad9a9efbe599d88b9ab792234592`

Focused adapter tests now pass (22 tests), including the exact patch-command environment case. The failure no longer warrants treating OC instability as the leading cause, though the next build must still be monitored and any repeated guest fault stops the run. CPU settings remain user-controlled.
