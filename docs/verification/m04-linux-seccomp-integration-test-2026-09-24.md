# M04 Linux seccomp integration probe

`tests/test_m04_linux_seccomp_integration.py` is a separately gated integration
test for the fixture capture runner. It creates a disposable marked directory,
checks one ordinary fixture install, then attempts `io_uring_setup` and expects
the kernel to return `EPERM`. The second event must be rejected by the runner
but remain persisted with a trace, event JSON, and hash-checked artifacts.

Run only on a disposable Linux test host with `bwrap`, `strace`, and Python
available, after explicitly opting in:

```sh
M04_RUN_LINUX_SECCOMP_INTEGRATION=1 python3 tests/test_m04_linux_seccomp_integration.py -v
```

Without the flag, off Linux, or without either required executable, the test
skips. It does not access `/mnt/lfs`, a Builder, or a VM disk. This narrow probe
does not cover the complete M04 acceptance matrix (mount boundaries, host
sentinels, inherited descriptors, metadata preservation, race resistance,
full trace completeness, or candidate-rootfs replay) and cannot establish
production readiness or count as a package ownership event. The test has not
been run as part of this change.
