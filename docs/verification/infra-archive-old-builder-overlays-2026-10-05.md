# Archived inactive Builder overlays — 2026-10-05

Two inactive preserved overlay sets were moved from the NVMe workspace to the HDD archive to protect the 15% free-space floor while the accepted base build grows. Their original directories were removed only after recursive file-size/SHA-256 equality checks passed and `qemu-img info --backing-chain` succeeded for each copied qcow2. The active Builder command line did not reference either set; their absolute backing paths continue to resolve to the unchanged milestone checkpoints on the NVMe.

- `preserved-overlays-1791178598777688707`: 2 files, 5,831,655,424 bytes. Receipt: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/archive-preserved-overlay-1791178598777688707.json`, SHA-256 `fa7122fae4597903213547a711b8b47513f8ac6b103c58924c6726c8953eab97`.
- `preserved-overlays-1791143893773412762`: 2 files, 6,366,625,792 bytes. Receipt: `/mnt/alpbahOS-data/alpbahos-infra-rebuild/logs/archive-preserved-overlay-1791143893773412762.json`, SHA-256 `b01ccaca5e9070cfafdf341237b58d7babf19a7a0c8b5148f1b0cabadd54fc55`.

Both archived copies are under `/mnt/alpbahOS-data/alpbahos-infra-rebuild/archives/preserved-builder-overlays/`. After the moves, free space was 35.79 GiB on `/mnt/alpbahOS-ssd` and 77.18 GiB on `/mnt/alpbahOS-data`, both above the 15% floor. The current 79-package base stage was still running; this archive record does not accept that build stage.
