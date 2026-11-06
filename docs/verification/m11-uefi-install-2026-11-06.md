# M11-UEFI-01 — UEFI install to a virtual disk and OVMF boot (2026-11-06)

Decisions: D136 (BIOS + UEFI), D138 (installer), D144 (root=PARTUUID).

## Prerequisites built in the 12.4 chroot
BLFS 12.4 rows 341 popt 1.19, 342 efivar 39, 343 efibootmgr 18, 344 dosfstools 4.2 (book MD5s matched: `eaa2135f…`, `a8fc3e79…`, `e170147d…`, `49c8e457…`). All four built with rc 0; `/usr/sbin/mkfs.vfat` and `/usr/sbin/efibootmgr` now exist in the chroot.

## Runner changes (`scripts/lfs-blfs/calamares/runner/m11-run.sh`, see `runner/README.md`)
- `M11_FIRMWARE=uefi`: GPT with a 512 MiB ESP (FAT32, made by the chroot's `mkfs.vfat`) + ext4 root; ESP mounted at `/boot/efi` before the bootloader step; globalstorage `firmwareType: efi`, `efiSystemPartition: /boot/efi`.
- Product `modules/bootloader.conf`: `efiBootloaderId: "alpbahOS"`, `installEFIFallback: true` (writes `EFI/BOOT/BOOTX64.EFI`).
- Host firmware protection (this host is a real UEFI PC): runner-only `grubInstall` wrapper adds `--no-nvram`; `efiBootMgr` points to `/usr/bin/false`; preflight and post-check fail if any efivars are visible in the chroot or the target.

## Run
`M11_FIRMWARE=uefi M11_SQUASHFS=<ISO mount>/LiveOS/squashfs.img M11_HOSTTOOLS=0 m11-run.sh <new image> <logs>` → rc 0 in 2 min 10 s; all modules rc 0; `[uefi-post] esp ok`. Logs: [m11-uefi-runner-logs/](m11-uefi-runner-logs/).

Host NVRAM check: `efibootmgr -v` on the Fedora host before and after the run — **identical** (`diff` empty).

## Boot (one QEMU boot)
`qemu-system-x86_64 -enable-kvm -machine q35 -m 2048 -smp 2 -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd -drive if=pflash,format=raw,file=<fresh copy of OVMF_VARS.fd> -drive file=<img>,format=raw,if=virtio -display none -serial file:… -monitor unix:…`

- Fresh VARS, so the firmware booted the fallback `EFI/BOOT/BOOTX64.EFI` (no NVRAM entry exists).
- Serial: `alpbahos login:` after ~16 s, **0 `FAILED`** lines ([m11-uefi-boot-2026-11-06.log](m11-uefi-boot-2026-11-06.log)).
- Journal (read-only mount): `efi: EFI v2.7 by EDK II`, `Secure boot disabled`, kernel command line `root=PARTUUID=2dc09c00-…` (matches the root partition), `Mounted /boot/efi.`, resolved and oomd started.
- ESP content: `EFI/alpbahOS/grubx64.efi`, `EFI/boot/bootx64.efi`. fstab: `UUID=8078-1359 /boot/efi vfat defaults,umask=0077 0 2`.

## Not covered / found
- The autologin Plasma session crashes with SIGILL in this boot too (default QEMU CPU model) — see [sigill-cpu-baseline-2026-11-06.md](sigill-cpu-baseline-2026-11-06.md). The install and boot path itself is fine.
- NVRAM registration on a real UEFI machine (`grub-install` without `--no-nvram`) is not tested; it is test-host-only that we skip it.
- Secure Boot is out of scope (D139).
</content>
