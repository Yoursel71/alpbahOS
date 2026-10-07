# 7 October 2026 — preserving old qcow2 archives on root NVMe

Two inactive, preserved qcow2 archives were relocated to the root NVMe to keep working SSD space available and avoid further writes to the nearly full HDD. The desktop stayed open; no user processes or CPU settings were changed. No QEMU process had either source archive open.

## SSD overlay branch

`/mnt/alpbahOS-ssd/alpbahos-infra-rebuild/preserved-overlays-1791295681168458973/` contained `builder-active.qcow2` and `lfs-active.qcow2` (7 GB apparent combined). Their backing files remain the accepted `checkpoint-toolchain` images on the SSD. Destination files under `/home/yrslf/.local/share/alpbahos-archives/infra/preserved-overlays-1791295681168458973/` matched both source SHA-256 values and passed `qemu-img check`. Only then were the SSD copies removed. Receipt: `archive-receipt.json`, SHA-256 `cc3a0efb7ac16593ab29fab02930bf01b49814f59a003caa12895d8668bd3738`.

## HDD stale-checkpoint archive

`/mnt/alpbahOS-data/alpbahos-infra-rebuild/archive/stale-checkpoints-inputs-df6426ac-20261003/` was a preserved checkpoint archive tied to old canonical inputs (9.6 GB apparent). It contains the stability and toolchain qcow2 overlays plus their metadata; their backing paths still point to the retained SSD checkpoint chain. The full source file list was hashed, the copy under `/home/yrslf/.local/share/alpbahos-archives/infra/stale-checkpoints-inputs-df6426ac-20261003/` was checked against those hashes, and all four qcow2 files passed `qemu-img check`. The HDD source was removed after verification. Receipt: `relocation-receipt.json`, SHA-256 `287debee7596f7f8a116933ae4ab33c153f9630de959412c7f8cfe9760d419b9`.

After relocation, free space was 56.2 GiB on root, 31.8 GiB on the SSD, and 71.9 GiB on the HDD. All remained above the 15% floor. Important milestone checkpoints and ISO files were left in place.
