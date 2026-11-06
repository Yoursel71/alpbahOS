# Live ISO builder

`build-iso.sh` builds the alpbahOS live ISO (`alpbahos-live-<YYYYMMDD>.iso`) from the LFS rootfs.
It reproduces the layout of the M09 ISO ([verification record](../../../docs/verification/m09-live-iso-2026-11-05.md)).

Status: script written and syntax-checked. Not run against a real rootfs yet. Boot and installer tests of its output are not done.

## Run

```text
sudo bash scripts/lfs-blfs/live-iso/build-iso.sh --out <new-empty-dir> [--make-initramfs] [--skip-tool-check]
```

- Must run as root on the Fedora host. It refuses to run otherwise.
- `--out` must not exist or be empty, and must not be under `/mnt`.
- The rootfs is only read, except for the optional `--make-initramfs` step (see below).

## Inputs

| Option | Default | Notes |
|---|---|---|
| `--rootfs` | `/mnt/lfs` | must be an LFS root (`usr/bin`, `etc`), not `/` |
| `--label` | `ALPBAH_LIVE` | must match `root=LABEL=` in `grub.cfg` and the `alplive` module (`rootfstype=iso9660`) |
| `--kernel` | `<rootfs>/boot/vmlinuz-6.16.1-lfs-12.4-systemd` | same file as the M09 `boot/vmlinuz` (same sha256) |
| `--initramfs` | `<rootfs>/boot/initramfs-live-6.16.1.img` | the M09 initramfs. Mutually exclusive with `--make-initramfs` |
| `--make-initramfs` | off | runs `chroot <rootfs> dracut` with the M09 options (see below) |
| `--skip-tool-check` | off | by default `check-live-tools.sh <rootfs>` must pass |

### Initramfs

The M09 initramfs was made with (from its `usr/lib/dracut/build-parameter.txt`, dracut-ng 112):

```text
--no-hostonly --no-kernel --add 'alplive' --omit '<systemd-related modules>'
```

`--make-initramfs` runs the same options in the chroot. It requires that the rootfs module
`usr/lib/dracut/modules.d/90alplive/` is identical to `dracut-alplive/` in the repo. The script
does not copy the module into the rootfs, so the rootfs must be prepared first. It writes a temporary
file under `<rootfs>/var/tmp` and removes it. The chroot mounts (`mount_lfs.sh`) must be in place.

## What goes into the squashfs

`mksquashfs <rootfs> LiveOS/squashfs.img -comp zstd -b 1M -noappend`, with these excludes:

- Whole entries: `dev proc sys run tmp mnt media` (created again as empty directories, see below).
- Build trees: `blfs-work`, `sources`, `tools`, `root/m11-runner`, `usr/lib/live`.
- Caches and temp contents: `var/cache/*`, `var/tmp/*`, `lost+found`.
- Test material: any `test-secrets`, `home/*/.bash_history`, `root/.bash_history`.

Empty directories are created with exact modes through pseudo definitions:

| Path | Mode | Why |
|---|---|---|
| `/tmp` | 1777 | systemd `PrivateTmp` and mount namespaces need it at first boot |
| `/root` | 0750 | root's home (LFS book mode). Kept from the rootfs, checked after the build |
| `/dev`, `/proc`, `/sys`, `/run` | 0755 | mount points that the installer and systemd need |
| `/mnt`, `/media` | 0755 | mount points |

### Why (M11-FIX-02)

The M09 squashfs was made by hand. It had no `/tmp`, `/root`, `/dev`, `/proc`, `/sys` or `/run`, and it
contained `/blfs-work`. On the first boot of an installed target, `systemd-resolved` and
`systemd-oomd` failed with `226/NAMESPACE` (`/tmp: No such file or directory`) while `/` was still
read-only. See [M11-FIX-02 root cause](../../../docs/verification/m11-fix02-root-cause-2026-11-06.md).

After the build the script reads the squashfs listing with `unsquashfs -ll` and fails if:

- `/tmp` is not `drwxrwxrwt`, `/root` is not `drwxr-x---`, or `/dev /proc /sys /run` are not `drwxr-xr-x` (owner `root/root`);
- `blfs-work`, `sources`, `tools`, `root/m11-runner` or `usr/lib/live` are present;
- a `test-secrets` path or a bash history is present;
- any file exists under `dev/ proc/ sys/ run/ tmp/`.

## Output

```text
<out>/alpbahos-live-<YYYYMMDD>.iso
<out>/SHA256SUMS
<out>/build-logs/   (mksquashfs, dracut, grub2-mkrescue, xorriso logs)
```

The ISO tree (`iso/boot/vmlinuz`, `iso/boot/initramfs-live.img`, `iso/boot/grub/grub.cfg`,
`iso/LiveOS/squashfs.img`) is a temporary staging directory. It is removed after a successful build and
also after a failed one.

`grub2-mkrescue -volid <LABEL>` writes a hybrid image with an El Torito BIOS entry and an EFI entry.
The M09 ISO had both (checked with `xorriso -report_el_torito`). The script checks the same two
entries and the volume id. The EFI path is not tested.

On failure the script removes the partial ISO, SHA256SUMS and ISO tree it created, and keeps the logs.

## Host tools (Fedora)

`squashfs-tools` (`mksquashfs`, `unsquashfs`), `xorriso`, `grub2-tools-extra` (`grub2-mkrescue`),
`grub2-pc-modules`, `grub2-efi-x64-modules`, `coreutils`.

## Not verified

- The output has not been built. The rootfs currently fails `check-live-tools.sh` (no `rsync`, `unsquashfs`, `mksquashfs` in `/mnt/lfs`), so a run needs the rootfs fixed or `--skip-tool-check`.
- `--make-initramfs` has not been run. The dracut options come from the M09 record. Whether dracut works inside the chroot without `/dev` is not checked.
- Exclude patterns are checked only by the post-build listing check, not by a boot.
- The rootfs `/etc/shadow` may contain the test root password (handoff 023 says it was written and must be removed before release). This script does not remove it.
- UEFI boot, QEMU boot, and the installer run from the new ISO are not done.
