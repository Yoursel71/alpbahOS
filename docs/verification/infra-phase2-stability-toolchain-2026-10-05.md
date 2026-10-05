# Phase 2 stability and multilib toolchain acceptance — 5 October 2026

Canonical input SHA-256: `d120f4db2e8f69e107069f8c13e3800d76f3f5e2fcae8ee1d547097f209c13cf`. Source manifest SHA-256: `aa8cc629f81a0dbae69cfa0454724e3521a7b16a8c9e75e0ab12b135069e6abb`. Phase 1 acceptance SHA-256: `57197fe2958135b85689c42ccbf99b75a7482374afb37fc838178e439147ed1c`.

## Stability gate

Run `f2ad9cc4501f30eaf52b2d1b6648fdee` passed in `1208.464s`. Before/after host audit IDs: `293cc8b446ef48592094dfe9f06aa417` / `edd102dfe4c830df87ff608c02a797fc`. Acceptance SHA-256: `9759b722a4687d957614dc89a0c45219e0c5d9817d5baba43fcd8fdb444772b1`; checkpoint and transaction SHA-256: `60be4b42bd68667865ec9ce04184b9917afc0768595e1fe16ddb440f26e7d7a7` / `bd2b922df02bb3e9a9294bd3935b29ce9970d0a13a6fefc828a7f13337372322`.

Binutils 2.45 SBU was `112.589s` at `-j1` and `41.948s` at `-j16`; both staged archive hashes matched (`eb03c13dead6df319267db6050aebe5cc36cdafcafcf9d7f1485cd0c396f32b6`) and both manifest hashes matched (`a249a0e612159f84aa40e562210102a9f8a2f80f48ac712c74910106e325072a`). Repeated zlib builds also matched (`fd0e3858018f8b66a8a38e936982da7e85969f3f6efa6257007c248c19a2eebd` archive; `e76130a8486c7aed8ca1f8a9c28cfbee37d2dacbf42aaeffacb8b87ebf5830b2` manifest), and both raw Alp DB hashes were `7c672a455f5bc3b7152f282f3be087eb0c4571736bb1e5edf589b04561eecbc9`. All 16 stress workers reported success. Host monitoring recorded 119 samples, no telemetry/kernel faults, Tctl `46.875–61.25°C`; throttle-counter coverage remains unavailable.

## Multilib toolchain gate

Run `32e1aff3984813a864347abdda1c08f9` passed. The guest command exited 0 in `1009.470s`; before/after root audit IDs: `7a98cb6257f2914f2817402cfe4ed7da` / `bd22da6352362e1907e0939e46ffbf1c`. Guest evidence verified the seven selected components (`filesystem-layout`, `binutils-pass1`, `gcc-pass1`, `linux-headers`, `glibc-cross-m64`, `glibc-cross-m32`, and `libstdcxx-cross`) and successful m64 plus m32 ABI probes. Final guest Alp DB SHA-256: `76d403a2b83fe55ec17752e1ec14643efbd69cf31d188441f4333fe9104cc164`. Toolchain acceptance artifact SHA-256: `32f7b7aa58241b31cffd661178542980d4b6df6a735da2a407322ab69568ba4b`; checkpoint and transaction SHA-256: `b3e7e0f90a6983293840fd41f8efa9de47023583b161cf63b6294762e54b22b3` / `a54b0c31df6ed4af1c552d32c23e0cb366cdb4138776115d003d82c43cf660df`.

Host monitoring recorded 101 samples, no telemetry/kernel faults, Tctl `51.125–60.25°C`; throttle-counter coverage remains unavailable. Both root audits observed the same pinned pre-existing `rpm -Va --noscript` output hash `2ae99151a7213553c55656e37637870996a85e9cdceefea62d53ddd0370c2ead` (`pristine_rpm=false`). This proves no observed RPM drift during the gate, not a clean RPM verification.

Full toolchain logs, telemetry, guest packages/DB/ABI evidence, root audit requests and stage receipts are under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/32e1aff3984813a864347abdda1c08f9/`, `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs/32e1aff3984813a864347abdda1c08f9/`, and `/var/lib/alpbahos-infra-audits/32e1aff3984813a864347abdda1c08f9/`. The checkpoint is `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/checkpoint-toolchain/`.

The legacy toolchain checkpoint and PASS record for input `158562e52a6c078800061086bab1f12dbc8ef2aaaabcd7d36a66b2cb27ebf6d0` were archived before creating this checkpoint. The original checkpoint files remain at `/mnt/alpbahOS-data/alpbahOS-build/archives/alpbahos-infra-rebuild/checkpoint-toolchain-legacy-input-158562e5/`; its historical stability parent remains at `/mnt/alpbahOS-data/alpbahOS-build/archives/alpbahos-infra-rebuild/checkpoint-stability-legacy-input-158562e5/`. The legacy PASS record is `/mnt/alpbahOS-data/alpbahOS-build/archives/alpbahos-infra-rebuild/toolchain-acceptance-legacy-input-158562e5.json`.

These receipts accept only the stability gate and multilib toolchain. The 79-package base, kernel, BLFS, Plasma/KWin, profiles, and reproducible ISO remain separate stages.
