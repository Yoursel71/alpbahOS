# M11-FIX-02 — root cause of the resolved/oomd start failures (2026-11-06)

## Symptom
On the first boot of an installed target (M11 runs of 2026-11-06), `systemd-resolved` and `systemd-oomd` fail with `status=226/NAMESPACE` ("Failed to set up mount namespacing: /tmp: No such file or directory").

## Evidence (no new VM boot; read-only mount of the existing target)
Target: `scratch-lfs-bench/m11-runner/m11-target-d144-20261106.img` (booted once earlier, see [m11-d144-partuuid-2026-11-06.md](m11-d144-partuuid-2026-11-06.md)). Mounted with `losetup -r` + `mount -o ro`; journal read with the host's `journalctl -D <mnt>/var/log/journal -b -o short-monotonic`.

```
[1.420323] (emd-oomd)[96]: Failed to create destination mount point node '/run/systemd/mount-rootfs/tmp', ignoring: Read-only file system
[1.422673] (emd-oomd)[96]: systemd-oomd.service: Failed to set up mount namespacing: /tmp: No such file or directory
[1.423287] (resolved)[122]: systemd-resolved.service: Failed to set up mount namespacing: /tmp: No such file or directory
[1.428850] systemd[1]: Starting Remount Root and Kernel File Systems...
```

Both units use `PrivateTmp=disconnected` and `ProtectSystem=strict`, so systemd needs a `/tmp` mount point in the root. The units start at 1.42 s, before the root is remounted read-write (1.43 s), and `/tmp` does not exist yet, so the mount point cannot be created.

Why `/tmp` is missing: the squashfs used as installer source (`scratch-lfs-bench/alp-iso/LiveOS/squashfs.img`, made by hand for M09) has these top-level entries only: `bin blfs-work boot etc home lib lib64 media mnt opt sbin srv usr var` (from `unsquashfs -l`). There is no `/tmp`, `/root`, `/dev`, `/proc`, `/sys` or `/run`. The installer creates `/dev /proc /sys /run` as mount points; `/tmp` appears only after the first boot (systemd-tmpfiles), which is why a later read-only check of a booted target showed `/tmp`. `/root` (root's home) is missing as well, and the build directory `/blfs-work` is wrongly included.

## Fix
- Build the squashfs with a script that keeps the empty directories `/tmp` (1777), `/root` (0750, LFS book mode), `/dev /proc /sys /run` (0755) and excludes `blfs-work`, `sources`, `tools` and test material (`scripts/lfs-blfs/live-iso/build-iso.sh`).
- The installer runner checks that `/tmp` and `/root` exist after unpackfs.
- Acceptance: a new install from the rebuilt squashfs boots with no failed units (`systemctl --failed` empty, no `FAILED` on the serial console).

## Result (same day) — fixed
1. rsync 3.4.1 and squashfs-tools 4.7.5 built in the 12.4 chroot (BLFS rows 339/340; `live-iso/check-live-tools.sh /mnt/lfs` → exit 0). Note: upstream `unsquashfs -version` exits 1 on success, so the smoke test checks the printed version.
2. `scripts/lfs-blfs/live-iso/build-iso.sh --out scratch-lfs-bench/alp-iso-v2-20261106 --make-initramfs` → rc 0 in 1 min 38 s; 2.6 GB hybrid ISO (BIOS + EFI El Torito entries, label `ALPBAH_LIVE`); its own check passed: `/tmp` 1777, `/root` 0750 (LFS book mode), `/dev /proc /sys /run` 0755, no `blfs-work`, `sources`, `tools`.
3. Two more problems found and fixed on the way:
   - Under `tr_TR.UTF-8` the bash range `[A-Z]` does not match `I`, so the label check rejected `ALPBAH_LIVE` → the script now runs with `LC_ALL=C`.
   - The Fedora build host's SELinux labels (`security.selinux=…mnt_t`, 1339 files under `/usr/bin` alone) were packed into the squashfs → now excluded with `-xattrs-exclude '^security\.selinux$'` and checked after the build.
   - Installing on the SELinux test host, `rsync -X` then failed (exit 23) because it could not remove the label the host kernel puts on every new file of the loop-mounted target. Test-host only: the runner (with `M11_HOSTTOOLS=0`) puts a wrapper on the chroot's tmpfs `/run` that adds `--filter="-x security.selinux"`. The product rsync call is unchanged; the live ISO has no SELinux.
4. Install: `M11_SQUASHFS=<ISO mount>/LiveOS/squashfs.img M11_HOSTTOOLS=0 m11-run.sh <new image> <logs>` (the chroot's own rsync/unsquashfs, not Fedora copies) → rc 0, all modules rc 0. Logs: [m11-fix02-runner-logs/](m11-fix02-runner-logs/).
5. One QEMU BIOS boot: login prompt after ~12 s, **0 `FAILED` lines** on the serial console ([m11-fix02-boot-2026-11-06.log](m11-fix02-boot-2026-11-06.log)). Journal (read-only mount): `Started Userspace Out-Of-Memory (OOM) Killer` at 1.44 s, `Started Network Name Resolution` at 1.58 s. Installed root: `/tmp` 1777, `/root` 0750, no `/blfs-work`.

Not covered: UEFI install/boot, booting the new ISO itself in QEMU, the GUI installer.
</content>
