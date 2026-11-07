# REBUILD-R2 chapter 11 and boot test (2026-11-07)

Task / status: chapter 11 release files written. The `/mnt/lfs13` tree was installed on a sparse raw disk image (BIOS boot partition, 512 MiB ESP, ext4 root) and booted headless in QEMU with BIOS and with UEFI (OVMF). **Both boots pass** on the final image: login prompt on the serial console, zero `FAILED` lines, DHCP lease on virtio-net. The first BIOS boot exposed one real defect (systemd binfmt_misc automount failed). It was fixed by building `CONFIG_BINFMT_MISC=y` into the kernel and the image was rebuilt and both boots re-run.

Host: `thewo` (Fedora 44), build root `/mnt/lfs13`, worktree `/home/yrslf/alpbahOS/wt-t2-kisayol`, branch `claude/t2-kisayol-2026-11-05`. Image: `scratch-lfs-bench/images/alpbahos-r2-ch11-2026-11-07.raw` (raw, 20 GiB sparse, outside the repo). Logs: `scratch-lfs-bench/lfs13-logs/boot/`.

## 1. Results

| Boot | Firmware / machine | Accel, CPU | Login line on serial | `FAILED` lines | DHCP (journal) | qemu exit |
|---|---|---|---|---|---|---|
| BIOS, final image | SeaBIOS, i440fx (default) | TCG, `-cpu qemu64` | `alpbahos login:` (x2) | 0 | `ens3: DHCPv4 address 10.0.2.15/24, gateway 10.0.2.2 acquired from 10.0.2.2` | 0 (ACPI powerdown) |
| UEFI, final image | OVMF, `-machine q35` | TCG, `-cpu qemu64` | `alpbahos login:` (x2) | 0 | `enp0s2: DHCPv4 address 10.0.2.15/24, gateway 10.0.2.2 acquired from 10.0.2.2` | 0 (ACPI powerdown) |
| BIOS, run 1 (before fix, archived) | SeaBIOS, i440fx | TCG, `-cpu qemu64` | `alpbahos login:` (x2) | 0 | `ens3: DHCPv4 address 10.0.2.15/24, gateway 10.0.2.2 acquired from 10.0.2.2` | 0 (but binfmt_misc failed, section 4) |

- Accelerator: TCG only (`-cpu qemu64`, no `-enable-kvm`). Each boot reached the login prompt in about 20 s of guest time. `/dev/kvm` exists on the host, but the KVM run was not done.
- Serial line, exact text as logged: `alpbahos login: ` (the getty prompt; the login is not used, no password is set or entered).
- `Startup finished` (journal, last boot): BIOS final `Startup finished in 8.131s (kernel) + 12.091s (userspace) = 20.223s.`; UEFI `Startup finished in 8.715s (kernel) + 8.507s (userspace) = 17.222s.`
- The UEFI run used a fresh copy of `OVMF_VARS.fd` per run (`scratch-lfs-bench/lfs13-logs/boot/uefi-tcg-qemu64-1/OVMF_VARS.fd`); the host NVRAM was not touched.
- The journal check (offline, image mounted read-only, `journalctl -D <root>/var/log/journal -b`) found no failed unit in either final boot. The `-p err` lines that remain are listed in section 5.

Logs: [BIOS serial](rebuild-r2-ch11-bios-serial-2026-11-07.log), [UEFI serial](rebuild-r2-ch11-uefi-serial-2026-11-07.log), [BIOS journal](rebuild-r2-ch11-bios-journal-2026-11-07.txt), [UEFI journal](rebuild-r2-ch11-uefi-journal-2026-11-07.txt), and the run 1 pair [serial](rebuild-r2-ch11-bios-run1-binfmt-serial-2026-11-07.log) and [journal](rebuild-r2-ch11-bios-run1-journal-2026-11-07.txt).

## 2. Chapter 11 release files

`scripts/rebuild/ch11/01-release-files.sh` (run through `run-chroot.sh ch11 01 01`, `ALL OK`). The repo had no existing AlpbahOS `os-release` or `PRETTY_NAME` values to copy (grep found only build-script references), so the values are set in the script:

- `/etc/lfs-release`: `13.1-systemd-R2`
- `/etc/lsb-release`: `DISTRIB_ID="AlpbahOS"`, `DISTRIB_RELEASE="13.1-systemd-R2"`, `DISTRIB_CODENAME="rebuild-r2"`
- `/etc/os-release`: `NAME="AlpbahOS"`, `VERSION="13.1-systemd R2 (REBUILD-R2)"`, `ID=alpbahos`, `ID_LIKE=lfs`, `VERSION_ID="13.1-r2"`, `PRETTY_NAME="AlpbahOS 13.1-systemd R2"`

No passwords were set in `/mnt/lfs13`. The image has no changed root password either: the boot test only needs the getty prompt.

## 3. Image build

`scripts/rebuild/image/build-image.sh` (host, root). The script refuses to overwrite an existing image, and every destructive step checks that the target is `/dev/loopN` backed by the image file (`losetup -n -O BACK-FILE`).

Commands, in order:
1. `truncate -s 20G IMG`; `losetup --find --show --partscan IMG` gave `/dev/loop0` (the run 2 image was built on the same loop name).
2. `sgdisk --zap-all`, then `sgdisk -n 1:2048:+1M -t 1:ef02 -c 1:biosboot -n 2:0:+512M -t 2:ef00 -c 2:esp -n 3:0:0 -t 3:8300 -c 3:alpbahos-root /dev/loop0`. Resulting table:
   ```
   Number  Start (sector)    End (sector)  Size       Code  Name
      1            2048            4095   1024.0 KiB  EF02  biosboot
      2            4096         1052671   512.0 MiB   EF00  esp
      3         1052672        41943006   19.5 GiB    8300  alpbahos-root
   ```
3. `mkfs.vfat -F 32 -n ALPESP /dev/loop0p2`; `mkfs.ext4 -q -F -L alpbahos-root /dev/loop0p3`.
4. `rsync -aHAXx --numeric-ids` from `/mnt/lfs13/` with `--exclude=/sources --exclude=/tools --exclude=/proc/* --exclude=/sys/* --exclude=/dev/* --exclude=/run/* --exclude=/tmp/* --exclude=/root/isa --exclude=/var/tmp/*`. rsync runs as root, so the root-only `/mnt/lfs13/root` is copied; `/root/isa` is excluded. No other build directories were found under `/mnt/lfs13` (`find -maxdepth 4 -name 'build*'` shows only autotools `build-aux` directories, which were kept).
5. Root UUIDs: root `UUID` `7a4cfb0e-c8f0-4784-aafd-0b0789a9e2da`; ESP `UUID` `614B-34D5` (run 2, final image). The run 1 image had `b92165e9-a4b8-44ed-ad50-1c82142c7536` and `D4D6-D5DA`.
6. `/etc/fstab` in the image: placeholders replaced by `sed` (`UUID=7a4cfb0e-…` on `/`, `UUID=614B-34D5` on `/boot/efi`). The template in `/mnt/lfs13` is unchanged.
7. `/boot/grub/grub.cfg` in the image: the chapter 10 template filled with the root UUID, kernel line `linux /boot/vmlinuz-7.1.8-alpbahos root=UUID=7a4cfb0e-c8f0-4784-aafd-0b0789a9e2da ro console=ttyS0,115200 console=tty0`, `initrd /boot/initrd.img-7.1.8`.
8. `grub-install` inside a chroot of the image (the LFS grub, not the Fedora host grub, which is not installed on the host):
   - `chroot ROOT /usr/sbin/grub-install --target=i386-pc --boot-directory=/boot /dev/loop0` gave `i386-pc platformu için kuruluyor.` and `Kurulum tamamlandı. Hata bildirilmedi.` (installation finished, no error reported).
   - `chroot ROOT /usr/sbin/grub-install --target=x86_64-efi --removable --no-nvram --efi-directory=/boot/efi --boot-directory=/boot` gave the same two lines. `EFI/BOOT/BOOTX64.EFI` exists on the ESP (the script checks it).
   - `--no-nvram` means nothing was written to NVRAM or `efibootmgr`.
9. Unmount, `losetup -d`. The build log is at `scratch-lfs-bench/lfs13-logs/boot/build-image.log` (`OK image-build ROOT_UUID=7a4cfb0e-… ESP_UUID=614B-34D5`).

Not done: `initramfs` regeneration inside the image (not needed: dracut was run with `--no-hostonly`, and ext4, vfat and virtio-blk are built in).

## 4. Defect found and fixed: binfmt_misc automount

Run 1 (BIOS, image before the fix): the serial log was clean (login line, 0 `FAILED`), but the offline journal showed the binfmt_misc mount failing:

```
Kas 07 10:06:32 alpbahos systemd[1]: proc-sys-fs-binfmt_misc.automount: Got automount request for /proc/sys/fs/binfmt_misc, triggered by 476 ((systemd-userd))
Kas 07 10:06:33 alpbahos mount[500]: mount: /proc/sys/fs/binfmt_misc: dosya sistemi tipi 'binfmt_misc' bilinmiyor.
Kas 07 10:06:33 alpbahos systemd[1]: proc-sys-fs-binfmt_misc.mount: Mount process exited, code=exited, status=32/n/a
Kas 07 10:06:33 alpbahos systemd[1]: proc-sys-fs-binfmt_misc.mount: Failed with result 'exit-code'.
...
Kas 07 10:06:42 alpbahos systemd[1]: proc-sys-fs-binfmt_misc.mount: Failed with result 'start-limit-hit'.
Kas 07 10:06:42 alpbahos systemd[1]: proc-sys-fs-binfmt_misc.automount: Failed with result 'mount-start-limit-hit'.
```

The mount message is Turkish locale output; in English it is `unknown filesystem type 'binfmt_misc'`. Cause: `CONFIG_BINFMT_MISC=m` in the kernel config. The module exists (`/lib/modules/7.1.8-alpbahos/kernel/fs/binfmt_misc.ko`, `modules.alias` has `alias fs-binfmt_misc binfmt_misc`), but the kernel's on-demand module load for `fs-binfmt_misc` did not succeed in this boot, so the filesystem type was unknown when `systemd-userd` triggered the automount. The reason for the failed autoload was not isolated; building the driver in avoids the autoload altogether.

Fix:
- `scripts/rebuild/ch10/01-kernel-config.sh`: forced option `scripts/config --enable BINFMT_MISC` (with the reason in a comment), plus a `need '^CONFIG_BINFMT_MISC=y$'` check.
- `scripts/rebuild/ch10/02-kernel-build.sh`: `rm -rf "/lib/modules/$KVER-alpbahos"` before `make modules_install`, so the old `binfmt_misc.ko` is not left behind as a stale module.
- `scripts/rebuild/ch10/kernel-7.1.8.config` (= `/sources/kernel-7.1.8.config`, 12304 lines): one line changed, `CONFIG_BINFMT_MISC=m` to `CONFIG_BINFMT_MISC=y`. sha256 `39787a075069375ebfa1f84f9cb21007e5d290471989547a21e3406974b76197`.
- Re-run: `sudo run-chroot.sh ch10 01 02` (kernel build `make -j16`, 1891 s for the three scripts including kernfs; `ALL OK`), then `ch10 04 05` (dracut and initramfs re-made against the rebuilt modules; `ALL OK`). Kernel files in `/mnt/lfs13/boot`: `vmlinuz-7.1.8-alpbahos` and `System.map`, `config`, `initrd.img-7.1.8` (the initrd name is unchanged).
- Verified after the rebuild: `/boot/config-7.1.8-alpbahos` has `CONFIG_BINFMT_MISC=y`; `/lib/modules/7.1.8-alpbahos` has no `binfmt_misc.ko`; `modules.dep` has no `binfmt`.
- The image was rebuilt from scratch (new UUIDs above). Both boots were run again on it. The journal of the final boots shows no `binfmt_misc` line at all.

The rebuilt kernel does not change the generic x86-64 flags (`X86_NATIVE_CPU` still off). The kernel-module ISA audit (CPU-BASELINE-03) is still open and was not re-run on the rebuilt modules.

## 5. Journal and serial messages that remain (not fixed)

From the last boot of the final BIOS image (`journal-check.txt`), `-p err`:

```
Kas 07 10:43:55 alpbahos kernel: virt/tdx: TDX not supported by the host platform
Kas 07 10:44:03 alpbahos systemd-tmpfiles[568]: Failed to check if symlink source path '/run/host/io.systemd.NamespaceResource' exists: Bağ sadeleştirilmişti
Kas 07 10:44:03 alpbahos systemd-tmpfiles[568]: Failed to check if symlink source path '/run/host/io.systemd.MountFileSystem' exists: Bağ sadeleştirilmişti
Kas 07 10:44:03 alpbahos kernel: Error: Driver 'pcspkr' is already registered, aborting...
```

The same four lines appear in the UEFI boot (`uefi-tcg-qemu64-1/journal-check.txt`). None of them is a unit failure, and none of them is in the `Failed with result` list (that list is empty for both final boots). These were **not investigated** further: the `/run/host/...` tmpfiles check is probably a container-only symlink rule, and `pcspkr` is a built-in driver loaded again. The run 1 journal also has `floppy: module verification failed: signature and/or required key missing - tainting kernel` (`info` level, module signing is on but not enforced, by design in the ch10 config); it is not in the `-p err` output.

## 6. Snapshots

- `scratch-lfs-bench/lfs13-snapshots/before-ch11-2026-11-07/`: taken before any change to `/mnt/lfs13` (`sudo rsync -aHAXx /mnt/lfs13/`). rsync exit 23: only the SELinux xattr on the destination root could not be set; all files were transferred.
- `scratch-lfs-bench/lfs13-snapshots/after-ch11-2026-11-07/`: taken at the end, same command, same exit 23 for the same reason.

## 7. Cleanup

After the last test: `losetup -l` shows no lines, `mount | grep -c "r2\|scratch-lfs-bench"` shows 0, and the temporary mount directories `/mnt/r2-image`, `/mnt/r2-journal-ro` and `/mnt/r2-j` were removed. The run 1 image (`alpbahos-r2-ch11-2026-11-07-run1-nobinfmt.raw`) was deleted once the run 1 logs were archived; the logs in `docs/verification/` are the evidence for it.

The final image stays at `scratch-lfs-bench/images/alpbahos-r2-ch11-2026-11-07.raw` (about 11 GiB allocated).

## 8. Tests and checks

- `python3 tests/test_audit_isa.py`: RC 0.
- `python3 docs/handoffs/claude/tools/check_docs.py`: RC 0 (`0 finding(s) (broken-link=0, commit-ref=0, decision-ref=0, stale-term=0)`).

## 9. Not verified

- KVM (`-enable-kvm -cpu qemu64`) was not run; all boots were TCG.
- UEFI NVRAM registration was not tested (`--no-nvram` by design). The UEFI boot used a fresh OVMF_VARS, so it went through the fallback `EFI/BOOT/BOOTX64.EFI`.
- No login was performed on the booted system; the proof is the login prompt and the journal.
- The GRUB menu (5 s timeout) was not interacted with; the default entry booted.
- Only QEMU virtio NICs and virtio disks were tested. No real hardware.
- The kernel-module ISA audit (CPU-BASELINE-03) was not re-run after the kernel rebuild.
- The messages in section 5 were not investigated.
