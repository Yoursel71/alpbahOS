# Base run 76c9cfbdb809ba41e151802844c59efa: runtime symlink guard

## Result

The run restored the accepted `checkpoint-toolchain` and used canonical input SHA-256 `abbd6785375cc5570ca89d0b5ba2d7227b9e61cdd6136a79b00baaed12b24a5b`. `iana-etc`, `man-pages`, and `ncurses` produced complete package receipts. Glibc's pinned test policy completed with 7,092 results: 6,984 PASS, 16 XFAIL, 91 UNSUPPORTED, and only the explicitly permitted root-only `stdlib/tst-system` failure. Its test-policy record reported no unexpected failures. Glibc's later 32-bit `others` build and complete package receipt were still in progress, so this Base run did not produce package acceptance, Base acceptance, or a checkpoint.

The controller outcome is `FAIL` because `buildctl.space_guard()` found an unexpected symlink at `/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/preserved-overlays-1791350318583462269`. While moving the previous failed-run overlay pair to HDD, I left a symlink at its former NVMe path to preserve the old reference. Runtime policy rejects symlinks anywhere in its mutable data and VM trees. The host disk telemetry remained above the configured 15% floor in all 384 samples (minimum free ratios: root 22.43%, SSD 15.42%, data/HDD 15.87%); telemetry recorded no kernel faults. The run stopped before the symlink was removed, and its active qcow2 overlays remain preserved on SSD.

The symlink has been removed. The archived prior-run pair remains at `/mnt/alpbahOS-data/alpbahos-infra-rebuild/archive/preserved-overlays-1791350318583462269/`; both archived qcow2 files passed `qemu-img check`. Both active overlays from this failed run also passed `qemu-img check`. A direct `buildctl.space_guard()` invocation passes with the corrected runtime tree, and the repository is unchanged by the host-side archive operation.

## Evidence

- Run ID: `76c9cfbdb809ba41e151802844c59efa`; controller SHA-256 `ab8522ca16e9948f254fc2e464b9f5b2abd0f88797b2be04e55c2a53a9011e1c`.
- Guest runner SHA-256: `d5693b692b043ebb831864122216d2a5bdab8540a71d7e2aadf7d66d6e901ff9`.
- Controller log: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/alpbahos-infra-base-20261007T051654Z-1631853.log`, SHA-256 `9cc1a28fbde0f9fbd9004d4a5e42751ea1282460b659e8a28e28bb66d7f5c61a`.
- Host telemetry: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/76c9cfbdb809ba41e151802844c59efa/base.host.jsonl`, SHA-256 `f2231e45382bb5a81e2cc867d013569237d5e8b8bd1fb7774f88402e6fa20946`.
- Outcome: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/state/stage-runs/76c9cfbdb809ba41e151802844c59efa/outcome.json`, SHA-256 `90d0b1fc529c5048f7ffa278ee847a8f5820e0e60e6034c2629b643e230a21a7`.
- Partial guest evidence: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/artifacts/stage-runs/76c9cfbdb809ba41e151802844c59efa/guest-base-partial/`.

This report records a failed execution and the corrected runtime tree. It is not Base acceptance.
