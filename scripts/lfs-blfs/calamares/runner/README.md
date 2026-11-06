# M11 installer runner

`m11-run.sh` runs the Calamares 3.3.14 install modules one by one (`loadmodule`)
inside the LFS chroot (`/mnt/lfs`) against a NEW sparse disk image. It never
touches a real disk. Modules: unpackfs, machineid, localecfg, fstab, networkcfg,
hwclock, grubcfg, bootloader, umount. The partition, mkfs and mount steps are
done by the script itself (see the header of `m11-run.sh`).

## Status

| Mode | Script | Evidence |
|---|---|---|
| `bios` (default) | unchanged layout and steps | BIOS boot proven: [m11-d144-partuuid-2026-11-06.md](../../../../docs/verification/m11-d144-partuuid-2026-11-06.md), [m11-fix02-root-cause-2026-11-06.md](../../../../docs/verification/m11-fix02-root-cause-2026-11-06.md) |
| `uefi` | written 2026-11-06 (M11-UEFI-01) | Static only: runner logic run against stubs (see "Checks run"). Real run, OVMF boot: not run |

## Usage

```
sudo bash m11-run.sh <NEW-target.img> <log-dir>                       # BIOS (default)
sudo M11_FIRMWARE=uefi bash m11-run.sh <NEW-target.img> <log-dir>     # UEFI
```

The target file must not exist. The script refuses to reuse one. `M11_FIRMWARE`
accepts only `bios` or `uefi`; any other value stops the run before anything is written.

## Disk layouts

| Partition | BIOS mode | UEFI mode |
|---|---|---|
| p1 | BIOS boot, 1 MiB, GUID `21686148-6449-6E6F-744E-656564454649` | EFI System, 512 MiB, GUID `C12A7328-F81F-11D2-BA4B-00A0C93EC93B`, FAT32, label `ALPESP` |
| p2 | ext4 root, label `alpbah-root`, rest of the image | same |

Both modes: GPT, root on p2, root PARTUUID is the value in `grub.cfg`.

## Installed-system boot (both modes)

- No initramfs in the installed system. The kernel gets `root=PARTUUID=…`
  (D144, set by `modules/grubcfg.conf`, which writes `GRUB_DISABLE_LINUX_UUID=true`
  and `GRUB_DISABLE_LINUX_PARTUUID=false`).
- The kernel config (`/mnt/lfs/boot/config-6.16.1`, read 2026-11-06) has
  `CONFIG_EFI=y`, `CONFIG_EFI_STUB=y`, `CONFIG_EFI_PARTITION=y`, `CONFIG_VFAT_FS=y`,
  `CONFIG_NLS_CODEPAGE_437=y`, `CONFIG_NLS_ISO8859_1=y`. The FAT driver is built in,
  so `boot-efi.mount` can mount the ESP at boot without an initramfs.

## Calamares globalstorage keys set by the runner (UEFI)

Source: `/mnt/lfs/sources/blfs-build/calamares-3.3.14/src/modules/` (read-only).

| Key | Value | Why (main.py line) |
|---|---|---|
| `firmwareType` | `efi` | bootloader `run()` picks the EFI path; mount `main.py:366`; grubcfg `main.py:307` |
| `efiSystemPartition` | `/boot/efi` | bootloader `prepare_bootloader` `main.py:883` (EFI dir for grub-install); `run()` `main.py:919-920` requires a partition with this mountPoint, otherwise bootloader and grubcfg silently do nothing (`grubcfg main.py:320-326`) |
| `partitions[p1]` | `device` `<loop>p1`, `fs: fat32`, `mountPoint: /boot/efi`, `uuid`, `partuuid` | fstab maps `fat32` to `vfat` (`fstab main.py:55-57`) and writes `UUID=<uuid>` (`main.py:286`) |
| `mountOptionsList` (`/boot/efi`) | `defaults,umask=0077` | same options as the Calamares `mount.conf` example for the `efi` filesystem |
| `bootLoader.installPath` | `null` | only the BIOS branch uses it (`bootloader main.py:645`); UEFI never writes an MBR |
| `branding.bootloaderEntryName` | `alpbahOS` | `efi_label` (`main.py:428-439`) gives the EFI directory and `--bootloader-id` |

Product config `modules/bootloader.conf` (also copied into the runner):

| Key | Value | Why |
|---|---|---|
| `efiBootLoader` | `grub` | `prepare_bootloader` (`main.py:847`) takes the `grub` branch; `sb-shim` is the only path that calls efibootmgr |
| `efiBootloaderId` | `alpbahOS` | fixed EFI directory name; without it the name comes from branding (the default branding file says `FancyGL`) |
| `installEFIFallback` | `true` | `install_grub` copies `EFI/alpbahOS/grubx64.efi` to `EFI/BOOT/BOOTX64.EFI` (`main.py:705-714`); this key was already `true` |

Runner-only copy `/root/m11-runner/bootloader-uefi.conf` (generated from the
product file; the product file is not changed for this):

| Key | Value | Why |
|---|---|---|
| `grubInstall` | `/usr/local/sbin/grub-install-no-nvram` | wrapper that runs `grub-install --no-nvram "$@"` (see below) |
| `efiBootMgr` | `/usr/bin/false` | efibootmgr is called only from `install_secureboot` (`main.py:775`) and `efi_boot_next` (`main.py:454`). Not reached with `efiBootLoader: grub`; if it ever is, it fails instead of writing NVRAM |

grub-install call made by the bootloader module (`main.py:632-638`), after the
wrapper expands it:
`grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=alpbahOS --force --no-nvram`

## NVRAM safety (host firmware must not change)

The host is a real UEFI PC with Fedora and Windows boot entries. The runner
prevents writes to host firmware variables in four ways:

1. **`--no-nvram` wrapper.** `--no-nvram` tells `grub-install` not to add a firmware
   boot entry (GRUB option; behaviour taken from the GRUB manual, not re-read from
   the GRUB 2.12 source or tested here). The wrapper adds the flag on every call. The wrapper is
   written to `$TGT/usr/local/sbin/grub-install-no-nvram` before the bootloader
   step and removed right after it. The cleanup trap also removes it on error.
2. **No efivarfs.** The chroot and target `/sys` are fresh sysfs mounts, which do
   not contain efivarfs. Before the bootloader step (and again after it) the runner
   fails unless `$LFS/sys/firmware/efi/efivars` and `$TGT/sys/firmware/efi/efivars`
   are empty and no efivarfs is mounted under `/mnt/lfs`.
   Note: the Calamares `mount` module would mount efivarfs in the target
   (`/etc/calamares/modules/mount.conf` lines 37-40, `efi: true`). The runner does
   not run the mount module, so this does not happen here.
3. **`efiBootMgr=/usr/bin/false`** in the runner copy (see table above).
4. **Host check by the supervisor.** The runner does not run efibootmgr on the host.
   The supervisor must compare `efibootmgr -v` on the host before and after the run,
   and the two outputs must be identical.

## Post-checks (UEFI, hard fail)

Run by `m11-run.sh` after the bootloader step, before umount:

- ESP is mounted at `$TGT/boot/efi`.
- `EFI/alpbahOS/grubx64.efi` exists.
- `EFI/BOOT/BOOTX64.EFI` exists (FAT is case-insensitive, so the lookup ignores case)
  and is byte-identical to `grubx64.efi`.
- `boot/grub/grub.cfg` contains `root=PARTUUID=<root partuuid>` (checked in both modes).
- fstab has the root line and the ESP line `UUID=<esp uuid> /boot/efi vfat`.
- The wrapper is gone.
- After umount: `e2fsck -f -n` on root, and `fsck.vfat -n` on the ESP (both must be clean).

## Deviations from the Calamares run

- The ESP is mounted by the runner after unpackfs, not by the mount module first.
  A vfat mount under `/boot/efi` during the rsync could make rsync fail on the vfat
  root (same failure class as the SELinux exit 23 seen on 2026-11-06).
- The runner's gs.yaml is hand-written; Calamares' partition module is not run.

## QEMU/OVMF boot (supervisor)

Use a fresh copy of the VARS file for every run. Then no NVRAM boot entry exists
and OVMF must boot the fallback `EFI/BOOT/BOOTX64.EFI` from the disk.

```
RUN=<per-run directory, new and empty>
IMG=<NEW-target.img produced by the runner>
cp /usr/share/edk2/ovmf/OVMF_VARS.fd "$RUN/OVMF_VARS.fd"
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file="$RUN/OVMF_VARS.fd" \
  -drive file="$IMG",format=raw,if=ide \
  -display none -serial file:"$RUN/serial.log" \
  -monitor unix:"$RUN/mon.sock",server,nowait
```

No `-cdrom`. Watch `serial.log` for the login prompt (`alpbahos login:`).
Power off with ACPI through the monitor: send `system_powerdown` to `mon.sock`
(e.g. with `socat`, if installed; not verified here). Expect `reboot: Power down`
and QEMU exit 0, as in the BIOS run.

Files in `/usr/share/edk2/ovmf/` on this host (checked 2026-11-06): `OVMF_CODE.fd`,
`OVMF_VARS.fd` (the 2 MB pair used above) and `OVMF_CODE_4M.qcow2` / `OVMF_VARS_4M.qcow2`
(other variant, not used here).

## Checks run (2026-11-06)

All checks below are static or stub-based. None of them touched `/mnt`, a real disk or host NVRAM.

- `bash -n` on `m11-run.sh`: ok.
- `python3 -I` YAML parse of `modules/bootloader.conf` and of the generated UEFI
  `gs.yaml` and `bootloader-uefi.conf`: ok.
- Sandbox run of the script with the real `/mnt/lfs` path replaced, and with `chroot`,
  `losetup`, `mount`, `umount`, `mountpoint`, `blkid` and the Calamares modules stubbed
  (stub modules write the files the real modules write, as read from the sources).
  Scratch files only under the session scratchpad.
  - BIOS: the original script and the new script produce identical sfdisk input,
    gs.yaml, /etc (target) and grub.cfg. The only difference is the loop log line,
    which now also prints `fw=bios`.
  - UEFI happy path: rc 0; sfdisk, gs.yaml, fstab, bootloader-uefi.conf, ESP files and
    post-checks as expected; no mounts or wrapper left.
  - UEFI negatives, each stopped with a hard fail: a non-empty efivars directory
    (preflight); missing `mkfs.vfat` (preflight); `M11_FIRMWARE=bogus`; bootloader
    failure (wrapper removed anyway); no fallback copy (`BOOTX64.EFI` check); no ESP line
    in fstab.
- Not run: the real loadmodule with real Calamares, a real loop image, `grub-install`
  itself, the OVMF boot, the host `efibootmgr` comparison, and `fsck.vfat` on a real image.
  These need the supervisor (root, `/mnt/lfs`, the dosfstools build, and OVMF).

## Open items for the supervisor

- The chroot needs `usr/sbin/mkfs.vfat` and `usr/sbin/fsck.vfat` (dosfstools 4.2). The
  preflight stops the run if they are missing. Packages 341-344 in
  `build-cmds/packages/` cover popt, efivar, efibootmgr and dosfstools; their build
  status is not checked here.
- The chroot GRUB must have the `x86_64-efi` modules (`/usr/lib/grub/x86_64-efi`).
  Present on 2026-11-06; the grub-install run itself is not verified.
