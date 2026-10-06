# Multilib toolchain acceptance — 6 October 2026

The Phase 2 `multilib-m32` toolchain stage passed for input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b` and source manifest SHA-256 `aa8cc629f81a0dbae69cfa0454724e3521a7b16a8c9e75e0ab12b135069e6abb`. It started from the accepted stability checkpoint and ran in the isolated, offline KVM Builder. The earlier interrupted attempt remains preserved as a failed execution and was not used as build input.

Run `ff1b264e6bc5b55d60bafa4c8ef46481` completed the filesystem layout, binutils pass 1, GCC pass 1, Linux headers, glibc cross builds for m64 and m32, libstdc++ cross build, and m32/m64 ABI probes. The guest byte verifier returned `VERIFIED_GUEST_BYTES`; the final Alp database SHA-256 is `665d075b4ee58a177e5c2cb3616889839aac04bd1a7f90e4a939d762eee2f9cd`.

The Builder powered off normally before post-stage inspection. Host audits before and after captured the same boot ID and the same pinned RPM verification baseline. `rpm -Va --noscript` returned 1 with the established output SHA-256 `2ae99151a7213553c55656e37637870996a85e9cdceefea62d53ddd0370c2ead`; this host is **not** described as RPM-pristine. The verify-script inventory was empty and the kernel journal cursor did not change. Host telemetry recorded 102 samples, Tctl 47–59.125 °C, and no monitor errors; throttle-counter coverage remains unavailable.

Evidence:

- Guest byte proof: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/ff1b264e6bc5b55d60bafa4c8ef46481/guest-artifact-proof.json`, SHA-256 `2f6f1c2885c7839eb313778fa46b62ba30cb4e1254949f467597e2115ea1ccda`.
- Acceptance: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/toolchain-acceptance.json`, SHA-256 `81430628d0793c5137299092cf5331ef0471ff3cb9965bd5345b2a746223936e`.
- Accepted checkpoint metadata: `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/checkpoint-toolchain/checkpoint.json`, SHA-256 `683359c64b46ce4989a97e008ff8a597d69e02c4669273ce6afbbe89863eb742`; transaction SHA-256 `ceac62979b3ba07e92c70adcb9a01139fd093a8dd0b551de2b83ab273a7e753e`.
- Host controller log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-toolchain-ff1b264e.log`.
- Before audit `7c83e792044c44706db6021b44ae1651`; after audit `e45ada0b341b2ec3227ff62f3257ff37`.

This accepts the multilib toolchain gate only. The next stage is the ownership-tracked 79-package LFS base; kernel, BLFS core, Plasma/KWin, profiles, reproducibility, and fresh ISO acceptance remain outstanding.
