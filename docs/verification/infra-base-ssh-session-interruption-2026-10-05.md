# Base-stage SSH session interruption and detached runner — 5 October 2026

## Result

Base run `8c3fa34507986406be0298fb269a26c7` did not complete and is not accepted. The host controller ended while the guest package command was still running. The guest later logged out the root SSH session and stopped `user@0.service`; that ended the package runner while it was extracting the Expect source. The Expect result contains `build-started.json` but no completed build/install receipt. The run has no `outcome.json`, base acceptance, or base checkpoint.

Before shutting down the idle guest, the result directory was copied to `artifacts/stage-runs/8c3fa34507986406be0298fb269a26c7/guest-base-partial-recovered/`. All **193/193** guest files matched their remote SHA-256 values. The capture contains **14 installed-package receipts** and 115,260,763 bytes. Its file-map SHA-256 is `aacbc7419478ffb776bcfea6153ac719faabbb82d20d2fbdbceb702cc3f1e99d`; the durable capture receipt is `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/8c3fa34507986406be0298fb269a26c7/guest-base-partial-capture.json` (SHA-256 `120dde7f232f0d1a04d080c7edcd84712709d986f784150175cf6be1fa6e39db`). These files preserve diagnostic/build evidence only; they do not prove complete base ownership.

The host monitor recorded a **215.5 second telemetry gap** after the controller was terminated. The recovery monitor then resumed sampling and found no host kernel faults or sensor errors. The gap is explicitly recorded in `monitor-recovery.json`; it is not represented as continuous coverage, so the run cannot pass host-stage acceptance. QEMU was powered off cleanly after confirming that no guest build process remained.

## Cause and correction

The guest command was attached to the root SSH login scope. When that session closed, systemd stopped `user@0.service` and its child runner. The host command also belonged to the interactive task session, which had already ended.

The host controller now starts the guest runner as a uniquely named **system service** with `systemd-run --no-block`, polls the unit until its recorded exit state is final, and requires both a successful exit and the run-bound `summary.json`. Guest output is retained by journald and copied into the host command log. The new `scripts/run-persistent-base-stage.sh` starts the unprivileged host controller in its **user systemd manager**, with a separate persistent log, so closing the terminal session does not own the controller lifetime.

## Verification

- Four focused tests cover input validation, shell syntax, success requiring a successful systemd result plus summary, and failure rejection.
- Two focused launcher tests check argument rejection and detached user-service/log configuration.
- A live guest smoke unit was launched over SSH, allowed the SSH session to close, and then read back as `ActiveState=inactive`, `Result=success`, with its output file present.
- A live host user-service smoke unit likewise completed after its launch command returned; `systemctl --user` reported `inactive/success` and its log contained the completion marker.
- `buildctl.inputs_digest()` remains `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf`, matching the accepted toolchain checkpoint. The host-only controller and top-level launcher are outside that build-input set.

## Follow-up run and lock handoff fix

Persistent run `7f347ce8ead80048f52284c389ade4fb` confirmed the detached host/guest services launch and shutdown path, but failed safely before the first package install. `package_install.guest_install_guard()` requires the Builder writer lock on FD 9; the transient system service had been started directly with Python, so systemd did not inherit the SSH shell's FD. Guest traceback: `OSError: [Errno 9] Bad file descriptor` at `scripts/infra/package_install.py:122`. The run has no package acceptance or checkpoint; the guest was powered off cleanly.

The host supervisor now releases FD 9 in its SSH shell immediately before starting the service. The service executes the guest guard itself and `exec`s the runner, so it acquires and retains FD 9 for the whole package run. Regression coverage checks release ordering and guard/runner launch. Focused supervisor tests: 4/4 pass; the complete suite passes **337 tests, 2 skipped** in 88.931 seconds. Log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/infra-full-tests-lock-handoff-20261005.log`, SHA-256 `2b1fd2d950cbcb9ed6f354cd97fbb74c13bfa282987e2473a29a6131b2c79156`. `py_compile`, shell syntax, and `git diff --check` pass. The accepted toolchain input digest is unchanged. Commit/push and a fresh persistent base run follow. Kernel, BLFS, Plasma, profiles, and ISO work remain open.
