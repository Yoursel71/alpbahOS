# M08 PackageKit PATH and authorization retest — 30 September 2026

## Result

The earlier `DependsOn not supported by backend` failure is fixed in this candidate: the Alp PackageKit C plugin exports both `pk_backend_depends_on` and `pk_backend_required_by`, and Discover search for `htop` returns its catalog item. A second install failure was traced to PackageKit's intentionally filtered helper environment: it omits `PATH`, so GCC could not launch `cc1` while Alp built htop.

The Alp PackageKit helper now sets a fixed system executable path (`/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`) while retaining PackageKit-forwarded locale/proxy values. Reproduction on a disposable OverlayFS copy of the ISO root confirmed that the minimal PackageKit environment without `PATH` fails at `./configure --prefix=/usr` with `cc1: posix_spawnp: No such file or directory`; adding the fixed path made the same `alp install --yes htop` complete successfully. The preserved lower rootfs and existing ISOs were not modified by this reproduction.

## Latest ISO and live evidence

- NVMe ISO: `/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-safe-path.iso`
- HDD copy: `/mnt/lfs/mnt/alpbahos-builds/m10-live-iso-20260930T-packagekit-safe-path/alpbahOS-live-m10-pk-safe-path.iso`
- SquashFS includes the fixed-path helper and the rebuilt C plugin. `xorriso -report_el_torito` lists BIOS and UEFI boot entries; the candidate booted to the 1920×1080 Plasma session in QEMU.
- On the live guest, `pkcon install htop` advanced through Resolving, Starting, Testing changes and Finished, then entered Installing and displayed the graphical Polkit “Authentication Required” dialog. The old compiler rollback did not recur before authorization.
- The live image has locked `root` and `alpbahos` accounts, and `alpbahos` is not in `wheel`; the Polkit dialog offers root authentication. Therefore no valid admin credential was available for this disposable test. The request was not authorized, so install → launch → remove remains unverified. Do not report the PackageKit store gate as passed.

## Scope and next gate

`python3 -m pytest -q tests/test_m08_alp_packagekit_backend.py` passed 4 tests; `git diff --check` passed for the touched helper/tests. The isolated rootfs transaction proved the PATH fix for Alp, while the QEMU run proved live boot and the PackageKit-to-Polkit handoff. A successful admin approval, actual live `htop` installation/launch/removal, PackageKit refresh, and the displayed unknown-size issue remain open. Existing alpha ISOs were preserved.
