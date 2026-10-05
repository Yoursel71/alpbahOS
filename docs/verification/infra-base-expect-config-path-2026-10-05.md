# Base-stage Expect path correction — 2026-10-05

The first base run (`9aed64261bb33f977777a49d41274cea`) stopped at package 14, Expect 5.45.4. The preserved guest log ends with:

```text
configure: error: /usr/lib directory doesn't contain tclConfig.sh
```

The pinned LFS recipe uses `/usr/lib` and `/usr/include` because the book assumes a chroot where those paths refer to the target system. The isolated Builder runs package commands outside that target root, so Expect's configure probe checked the Builder's own `/usr/lib` and could not see the already installed Tcl package under `/srv/lfs`.

The guest runner now translates only the pinned Expect configure arguments, and only from `/srv/lfs/build/base-expect`, to `/srv/lfs/usr/lib` and `/srv/lfs/usr/include`. It verifies that `tclConfig.sh`, `tcl.h`, and `libtcl8.6.so` resolve inside the dedicated LFS root, adds that LFS library directory to `LD_LIBRARY_PATH` for the package's build/test commands, and rejects unexpected configure arguments. The adapter is part of the SHA-pinned guest runner; the canonical recipe and base input digest remain unchanged.

Validation: `python3 -m unittest discover -s tests -p 'test_infra_base_guest_runner.py' -v` passed 20 tests; `py_compile` and `git diff --check` passed. These are adapter tests only. They do not prove Expect builds or the 79-package base stage passes.

The failed run's full artifact directory is retained at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/9aed64261bb33f977777a49d41274cea`; its partial guest evidence includes the failing Expect log and the 13 prior package installation receipts. No base acceptance or base checkpoint was issued. Recovery is from the accepted toolchain checkpoint; the failed QCOW2 overlays must remain preserved before that recovery.
