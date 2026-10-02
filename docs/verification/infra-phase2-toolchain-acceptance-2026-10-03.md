# Phase 2 stability and toolchain acceptance — 3 October 2026

Current canonical input SHA-256: `df6426ac734f84cbde8fec23adb7d75d25e861db83fdfed8ada38447ea15a251`.

## Phase 1 smoke

The Phase 1 zlib smoke was rerun after the controller correction. Acceptance is recorded in `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/phase1-acceptance.json`; smoke summary SHA-256 `11f0031c40114e3023882f1166c42892445aeb3b00c37400bf577e1b9ffc616e`.

## Stability gate

Run `f9c28f7284f6fe3e89c270273e9e9f63` passed on the accepted m32/m64 configuration. Before/after root audit IDs: `57bed6404e2f24fa38bd993019b72e79` and `4ff3bd7348947620caac132929a5a67d`. Acceptance file SHA-256: `1961fbbd9b7700bcba4a787db329bb60685dd33adb0db22558bb0e94f93705ba`.

The stability receipt records 120 host telemetry samples, zero monitor errors, Tctl range 50–68°C, matching repeated zlib archive and package-manifest hashes, and matching raw Alp DB hashes. Throttle-counter coverage is unavailable and remains explicitly marked unavailable. `rpm -Va --noscript` exits 1 before and after with the same pinned existing-drift output hash; this proves no observed RPM drift during this stage, not host cleanliness.

## Multilib toolchain gate

Run `8b76ccbdf744511554afa9a4178fec73` passed guest evidence verification and host acceptance. The guest built the seven selected Chapter 4/5 components (`filesystem-layout`, `binutils-pass1`, `gcc-pass1`, `linux-headers`, `glibc-cross-m64`, `glibc-cross-m32`, `libstdcxx-cross`) and recorded successful m64/m32 ABI probes. Before/after root audits: `d274e85bc888ea5736eb5f7041b2b8d7` / `2067d45d1491e662bae03753194241cb`. The accepted Alp DB SHA-256 is `2031d23c087efa018d7adbdd49278fce6d55fcf0501fb4a6b5b2f0c30d38d854`.

Toolchain acceptance artifact SHA-256: `54c72352295f321f331fdebfbd91efb1bfe39e85373d95fd6cd6647407c04286`. Accepted toolchain checkpoint SHA-256: `9bee71e6d00438b6a306ee91bb978218d3c3126aaf98e0ad757d9053bb6daea6`; transaction SHA-256: `fc0c90122e1e6b82a8f48b755081bd06968e0fae1716f5e67eaf557b96f4cdc1`. Guest files, command record, telemetry, handoff, root audits and outcome are preserved under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/8b76ccbdf744511554afa9a4178fec73/` and `/var/lib/alpbahos-infra-audits/8b76ccbdf744511554afa9a4178fec73/`.

The controller fix is commit `5f36f3e`, pushed to `codex/infra-rebuild`. Full host/synthetic suite: 292 tests, 2 skipped, 88.962 seconds, PASS; command `PYTHONPATH=scripts/infra python3 -m unittest discover -s tests`.

## Preserved earlier checkpoint

The prior accepted stability checkpoint for input `4a2c2c79fa31013daac648746d64538b05f33ab5ff2252450e78c68f8ee251f0` was transferred from NVMe to HDD at `/mnt/alpbahOS-data/alpbahOS-build/archives/alpbahos-infra-rebuild/checkpoint-stability-pre-4a2c2c79fa31/checkpoint-stability/`. The rsync checksum dry run transferred/created/deleted zero files; source and destination SHA-256 matched for all four files; both HDD qcow2 images passed `qemu-img check`. Receipt: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/checkpoint-stability-offload-4a2c2c79fa31.json`.

## Remaining product work

These receipts accept the smoke, stability gate and multilib toolchain only. The 79-package LFS base stage, kernel, BLFS, Plasma/KWin, profile layer and reproducible ISO remain separate. Root disk was 73 GiB free, the NVMe workspace 46 GiB free, and HDD 264 GiB free after the toolchain checkpoint. KDE/Wayland remained active.
