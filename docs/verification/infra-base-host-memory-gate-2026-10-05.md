# Base run stopped at host memory gate — 5 October 2026

## Result

Base run `83b4fc6652621dc56da289a61c74d746` restored fresh Builder and LFS overlays from the accepted toolchain checkpoint, recorded its before-run host and repository evidence, and stopped before QEMU launch. The existing launch guard requires at least 12 GiB `MemAvailable` so an 8 GiB guest leaves a 4 GiB host reserve. The host had less than this threshold, so no guest boot or package action occurred. The run outcome is `FAIL`, with no guest artifact evidence and no base acceptance/checkpoint.

Authoritative evidence:

- Outcome: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs/83b4fc6652621dc56da289a61c74d746/outcome.json`
- Host log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-infra-base-20261005T202257Z-953369.log`
- Outcome error: `RuntimeError('Need 8 GiB guest RAM plus 4 GiB host reserve')`
- At follow-up measurement, `/proc/meminfo` reported `MemAvailable=11396116 kB` (about 10.9 GiB), below `12582912 kB` (12 GiB).

## Continuation

A user systemd service, `alpbahos-infra-base-memwait-v2-20261005`, checks `MemAvailable` once per minute and starts a new persistent base-stage controller only when the 12 GiB safety threshold is met. It uses negligible resources while waiting and does not terminate the desktop or user applications. The failed run remains preserved and is never replayed; the waiter will create a fresh run after the host has enough available memory.

The accepted toolchain input digest remains `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf`. No 79-package base-stage acceptance has been achieved yet.
