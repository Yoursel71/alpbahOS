# M04 Linux seccomp integration probe

`tests/test_m04_linux_seccomp_integration.py` is a separately gated integration
test for the fixture capture runner. It creates disposable marked directories,
checks one ordinary fixture install, attempts to write the read-only bound
capture `root-id` (expecting `EROFS` and a persisted syscall/errno attempt),
then attempts `io_uring_setup` and expects the kernel to return `EPERM`. The
two rejected events must remain persisted with traces, event JSON, and
hash-checked artifacts; the root identity must remain unchanged.

Run only on a disposable Linux test host with `bwrap`, `strace`, and Python
available, after explicitly opting in:

```sh
M04_RUN_LINUX_SECCOMP_INTEGRATION=1 python3 tests/test_m04_linux_seccomp_integration.py -v
```

Without the flag, off Linux, or without either required executable, the test
skips. It does not access `/mnt/lfs` or a VM disk; running it on Builder may
require Bubblewrap and strace on the Builder Ubuntu host, outside the rootfs.
This narrow probe
does not cover the complete M04 acceptance matrix (mount boundaries, host
sentinels, inherited descriptors, metadata preservation, race resistance,
full trace completeness, or candidate-rootfs replay) and cannot establish
production readiness or count as a package ownership event. The test has not
been run on Linux as part of this change.
