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

## Next step

Commit and push the runner fix, then relaunch the base stage using `scripts/run-persistent-base-stage.sh`. The stage must restore from the accepted toolchain checkpoint and produce a fresh continuous host record, complete 79-package guest summary, ownership evidence, post-audit, acceptance, and checkpoint. Kernel, BLFS, Plasma, profiles, and ISO work remain open.
