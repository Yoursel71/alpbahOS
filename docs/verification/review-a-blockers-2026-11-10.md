# Review section A (blockers for the real-PC USB test), round 20, 2026-11-10

Source: an external static review of commit 24b7c85 (r19) and the user's master task of 2026-11-10, section A.
Nothing was booted in that review, so each finding was first checked against the tree and r4-root.
Host `thewo` (Fedora, Ryzen 7 5700, 23 GiB RAM), worktree `/home/yrslf/alpbahOS/wt-t2-kisayol`, data in
`scratch-lfs-bench/` (not in the repo). Builds ran as root on the host with chroot builds in `r4-root`; guests ran under
KVM with `-cpu qemu64` (D146). No real disk, host `/boot` or NVRAM was written. The host was not rebooted.

## 1. Findings: confirmed or not

| Item | Review claim | Checked in the tree | Verdict |
|---|---|---|---|
| A1 | linux-firmware, wpa_supplicant and iwd are nowhere in the build; the ISO enables systemd-networkd, not NetworkManager | NetworkManager 1.58.1 was built (packages.tsv row 064, Wi-Fi device plugin `libnm-device-plugin-wifi.so`), and so was plasma-nm 6.7.4 (row 307, applet `usr/lib/plugins/plasma/applets/org.kde.plasma.networkmanagement.so`). wpa_supplicant and iwd: absent. `/usr/lib/firmware`: 0 bytes. Enabled in r4-root: `systemd-networkd.service` plus four networkd sockets; NetworkManager not enabled. Extra: NM `conf.d/dhcp.conf` had `dhcp=dhcpcd` (dhcpcd not installed) and `no-dns-update.conf` had `dns=none` while `/etc/resolv.conf` is the systemd-resolved stub. Extra: Calamares 3.3.14 `services-systemd/main.py` reads only `units:`; the `services:`/`targets:` keys in our config were ignored, so that installer step did nothing | Partly confirmed (NM and plasma-nm existed) |
| A2 | Installed user gets UID 1001: the live user holds 1000 and the users step runs before the live cleanup | settings.conf exec order: `users` before `shellprocess@live-cleanup`; build-iso.sh `useradd -u 1000 ... live`; r19 BIOS install `/etc/passwd`: `testuser:x:1001:1001`. Extra (found while fixing): `/` of the r19 installed system is owned by `1000:1000` (the top directory of r4-root belongs to the build user; mksquashfs and unpackfs carry it). With only the reorder, the first user would own `/` | Confirmed, plus a worse related defect |
| A3 | target-cleanup.sh always exits 0 | `set -u`, `userdel -r live 2>/dev/null \|\| true`, final `exit 0`: a failed removal left the install "successful" | Confirmed |

SDDM `MinimumUid=1000`, `MaximumUid=60000`; `/etc/pam.d/sddm-autologin` is `pam_permit` with no UID test. So the live user
keeps UID 1000 and the fix is the order of the installer steps, not a different live UID.

## 2. What changed

Commits: `bcdb764` (A1, NET-FW-01), `1854988` (A2, INSTALL-UID-01), `df76056` (A3, INSTALL-CLEANUP-01); test harness and this record in the round 20 evidence commit.
Decisions D147 to D150. r4-root was snapshotted read-only first (`r4-snapshots/r4-before-r20-2026-11-10`).

### 2.1 A1 (NET-FW-01, D147, D150)

| Step | Where | Result | Log |
|---|---|---|---|
| linux-firmware 20261019 | tarball sha256 `a10d1ab5baf2c74ba92e8c7cf313e691696c26bddfa6df00db795e48d70cd4ca` = the line in kernel.org `sha256sums.asc`; signature "Good signature from Kernel.org checksum autosigner", key `B8868C80BA62A1FFFAF5FDA9632D3A06589DA6B1` (WKD), on the host | OK | `scratch-lfs-bench/r20/dl/` |
| `copy-firmware.sh -j1 --zstd`, chroot of r4-root (`firmware-r20.sh`) | 4677 files, 2603 symlinks, 1,005,054,022 bytes staged; recorded as alp `linux-firmware 20261019` (7264 entries); `/usr/lib/firmware` 979 MiB. 0 x86-64 ELF files in the stage (no ISA audit target). No dedup (rdfind not in r4-root); microcode files stay uncompressed (upstream script) | OK | `r20/firmware-r20.log`, `r10/linux-firmware/build.log` |
| Kernel config | `CONFIG_FW_LOADER_COMPRESS=y`, `_XZ=y`, `_ZSTD=y` (`/boot/config-7.1.8-alpbahos`) | zstd firmware loads | — |
| wpa_supplicant 2.12 (`wpa-r20.sh`) | book MD5 `3f1af56655ebca941d2035358331bbc9` matches; sha256 `08e23937e16d0155e55cab2b51f51fbe10d80a1aa91c4e15442645059b737ef6`. Upstream `.asc` not checked: key `EC4AA0A991A5F2464582D52D2B6EF432EFC895FA` not on keys.openpgp.org or keyserver.ubuntu.com. Book `.config` + NetworkManager D-Bus block; deviation: `CONFIG_SAE=y`, `CONFIG_OWE=y` (WPA3-Personal, Enhanced Open). `-march=x86-64 -mtune=generic` in the V=1 log; ISA audit `3 file(s) scanned, 0 ... unallowed` | OK, recorded (13 entries) | `r20/wpa-r20.log`, `r10/wpa_supplicant/build.log` |
| NetworkManager config (`nm-conf-r20.py`, record `networkmanager-alpbahos-r20 0.9-r20`, REPLACE=1) | `dhcp=internal`, `dns=systemd-resolved`; the two BLFS files moved from the NetworkManager record (`transfers.tsv`) | OK | `r20/rec-nm-conf.log` |
| Units (`net-units-r20.sh`, offline systemctl in the chroot) | disabled: `systemd-networkd.service`, `.socket`, `-varlink.socket`, `-varlink-metrics.socket`, `-resolve-hook.socket`, `systemd-network-generator.service`, alias `dbus-org.freedesktop.network1`; enabled: `NetworkManager.service` (with dispatcher and wait-online) | OK | `r20/net-units.log` |
| Calamares `services-systemd.conf` | rewritten with `units:` (NM enable, networkd units disable, all mandatory) | in ISO r20 | — |
| `build-iso.sh` | refuses a root without NM enabled, wpa_supplicant or firmware, or with any networkd unit enabled | passed in the r20 build | `lfs13-logs/iso-beta-0.9/build/` |
| iwd | not built: NetworkManager needs one Wi-Fi backend, and wpa_supplicant is the BLFS path | — | — |
| Applet | the panel layout (`profiles/desktop/lookandfeel/.../org.kde.plasma.desktop-layout.js`) adds `org.kde.plasma.systemtray` with no item list, so the tray shows its default items | see 3.2 (B1D applet screenshot) | — |

Initramfs (D150): the GPU and Wi-Fi drivers that load firmware are not in the live initramfs, so their firmware comes
from the root file system after the switch. Exception: `mt7921s` (SDIO) and `mt7921-common` are pulled in by dracut,
without their firmware; PCIe `mt7921e` is not in the initramfs. dracut now adds the firmware of the storage drivers it
includes (113 firmware entries). Size of `boot/initramfs-live.img`: r19 43,777,340 bytes, r20 55,187,481 bytes.

### 2.2 A2 (INSTALL-UID-01, D148)

- New `shellprocess@live-user` (`target-live-user.sh`) after `unpackfs`, before `users`: removes the live user, group
  and home, then fails the install unless UID/GID 1000 are free, no file on `/` (one file system) belongs to UID/GID
  1000, and `/` is `0:0`.
- `build-iso.sh`: `chown 0:0` on the live copy's `/`; excludes `root/libp-dbg` and `root/build-libplasma-dbg.sh`
  (a libplasma debug tree of 2026-11-08, 944 files owned by UID 1000); refuses a squashfs with any UID/GID 1000 entry
  outside `/home/live` or with `/` not `0/0` (`unsquashfs -lln`).
- The live user keeps UID 1000: SDDM MinimumUid and the autologin PAM stack need no change.

### 2.3 A3 (INSTALL-CLEANUP-01, D149)

- `target-cleanup.sh`: removals of the live user, live polkit rule, live-only helpers, `/etc/calamares` and the sddm
  autologin user (all `[Autologin]` sections in `sddm.conf`, `sddm.conf.d`, `/usr/lib/sddm/sddm.conf.d`), followed by
  post-checks; also no polkit rule names the live user, no account has an empty password field, `/` is `0:0`. Any
  failed check: exit 1, the Calamares job fails.
- Test hooks (kernel command line, read from `/proc/cmdline`, which the mount module provides in the target):
  `alpbahos.testfail=live-user`, `alpbahos.testfail=live-cleanup`. They skip the removal only.
- After the r20 runs (review of this change, repo only, not in ISO r20): the cleanup no longer runs `userdel` (the
  live user is removed before `users`, so a late `userdel -r live` could only delete an account the user had just
  named `live`); the sddm reset touches only an `[Autologin]` section with `User=live`, so an autologin chosen on the
  installer's users page ("Parolayı sormadan kendiliğinden oturum aç", seen in `I1/i-05-users-filled.png`) is kept;
  the post-check accepts an autologin user only when it is an existing account other than `live`. Calamares
  `users.conf`: `user.forbidden_names: [ live ]` (the key is in `libcalamares_viewmodule_users.so`). Shown by the
  second chroot run (3.1); not yet in an ISO.

## 3. Checks run

ISO r20: `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-r20.iso`, sha256
**`d21f6e55e3f28b1da677286da4d0a4dedbbb2c1b27996067181519ae7ee3e5f3`**, 5,633,220,608 bytes (r19: 4,742,672,384 bytes;
+890,548,224 bytes, mostly firmware). Built by `sudo env TAG=r20 bash scripts/rebuild/iso/build-iso.sh` from the
r4-root snapshot `lfs13-snapshots/r4-iso-src-2026-11-09` (the r19 source snapshot was renamed `-prev-r19`); every
build gate passed, including the new network and UID 1000 gates (`scratch-lfs-bench/r20/build.log`).
Evidence directory: `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r20/`. Guests: KVM, `-cpu qemu64`, 6 GiB, virtio disk,
QEMU user network.

### 3.1 Offline checks

| Check | Environment, command | Result |
|---|---|---|
| A3 exit codes | host, `sudo bash scripts/rebuild/r20/a3-chroot-test.sh <r19 BIOS install> ...` (chroot of a CoW copy) | **PASS 7/7**: r19 image (`/` owned by 1000) fails the live-user check with `/` and `/root/libp-dbg` listed; normal removal rc 0; `alpbahos.testfail=live-user` rc 1; cleanup normal rc 0; cleanup rerun ("already gone") rc 0; `alpbahos.testfail=live-cleanup` rc 1 (live user, group, home, polkit rule, helper, polkit rule names live, empty password, sddm autologin `live`); sddm drop-in with `User=live` reset, rc 0 (`r20/a3-chroot-test.log`) |
| A3 exit codes, after the two fixes | host, same script on a CoW copy of the r20 BIOS install (its `testuser` removed first; `/` set to 1000 for case 1) | **PASS 13/13**: adds early step then cleanup (rc 0), drop-in reset after the early step (rc 0), installer-chosen autologin `User=testuser Session=plasma` kept (rc 0), an account named `live` after the users step is not deleted and the cleanup fails (rc 1, `live:1001` still there) (`r20/a3-chroot-test-2.log`) |
| alp ledger | host, `alp.py --root r4-root check` | rc 0, `Bağımlılık tutarlılığı: sorun yok (519 kurulu paket)`; `packages.tsv` rows 399 (linux-firmware) and 400 (wpa_supplicant) added (`r20/alp-check.txt`) |
| Installed initramfs (I1) | host, `lsinitrd` on the read-only I1 disk | `/boot/initramfs-7.1.8-alpbahos.img` 54,128,924 bytes; no GPU driver; Wi-Fi only `mt7921s`, `mt7921-common`, `mt792x-lib` (SDIO path, no firmware); 113 firmware entries (`r20/lsinitrd-installed-I1.txt`) |
| Firmware coverage, r4-root | host, `fw-coverage-r20.py r4-root 7.1.8-alpbahos` | **PASS**, rc 0, 0 missing (table below) (`r20/fw-coverage-r4root.txt`) |
| Firmware coverage, squashfs of ISO r20 | host, same script on the squashfs mounted read-only | **PASS**, rc 0, same table (`r20/fw-coverage-squashfs.txt`) |
| squashfs ownership | host, `stat`, `find -uid 1000 -o -gid 1000` on the mounted squashfs | `/` is `0:0`; 0 entries owned by UID/GID 1000 outside `/home/live` |
| squashfs network state | host, mounted squashfs | `multi-user.target.wants/NetworkManager.service` present, no networkd unit enabled; `dhcp=internal`, `dns=systemd-resolved`; `usr/lib/alpbahos/target-live-user.sh` present |

Firmware table (`modinfo -F firmware` over every module in each driver directory; "not shipped" = named by the driver
but not in linux-firmware's WHENCE, e.g. iwlwifi API levels above the newest shipped file, which the driver falls back
from):

| Group | Modules | Named | Shipped by linux-firmware | Present in image | Missing | Not shipped |
|---|---|---|---|---|---|---|
| iwlwifi | 7 | 61 | 31 | 31 | 0 | 30 |
| rtw88 | 31 | 10 | 10 | 10 | 0 | 0 |
| rtw89 | 20 | 6 | 6 | 6 | 0 | 0 |
| mt7921e | 4 | 8 | 8 | 8 | 0 | 0 |
| ath10k | 4 | 21 | 15 | 15 | 0 | 6 |
| amdgpu | 1 | 694 | 670 | 670 | 0 | 24 |
| i915 | 2 | 47 | 47 | 47 | 0 | 0 |
| xe | 1 | 35 | 35 | 35 | 0 | 0 |

### 3.2 QEMU rows on ISO r20

| Row | What | Result | Evidence |
|---|---|---|---|
| L1 | live UEFI, desktop at 130 s, Konsole checks | **PASS**: desktop with the tray network icon; `id`: `uid=1000(live)`; `ls -ldn /`: owner `0 0`; `systemctl is-active NetworkManager systemd-networkd systemd-resolved`: `active`, `inactive`, `active`; `nmcli device`: `enp0s2 ethernet bağlandı Kablolu bağlantı 1`; `resolvectl dns`: `Link 2 (enp0s2): 10.0.2.3`; `systemctl --failed`: `0 loaded units listed`. Live autologin still works (the desktop came up without a login) | `L1/l1-desktop-130.png`, `l1-id.png`, `l1-rootowner.png`, `l1-active.png`, `l1-nmcli.png`, `l1-resolvectl.png`, `l1-failed.png` |
| L1 curl | `curl -sSI -m 20 -o h.txt ftp.gnu.org` | **not a valid check**: without a scheme curl picks FTP for a host named `ftp.*`, so `h.txt` stayed empty (rc not captured). Replaced by the HTTP and HTTPS lines of B1D and U1D below | `L1/l1-curl0.png`, `l1-curl.png` |
| I1 | Calamares BIOS MSDOS install, Turkish Q, user testuser | **PASS** ("Her şey tamam") | `I1/i-09-done.png` |
| I1 disk | read-only loop mount (`disk-check-r20.sh`) | **PASS**: `/` `0:0`; `testuser:1000:1000`, group 1000 `testuser`; no `live` in passwd or group, `/home` = `testuser`; nothing else owned by UID/GID 1000; no empty password; `/etc/polkit-1/rules.d` empty; no `/usr/lib/alpbahos`, `/etc/calamares`, `alpbahos-install`, `/home/live`; sddm `[Autologin]`: `Relogin=false Session=` (no User line), no drop-in User line; NM enabled, 0 networkd units enabled; firmware 4677 files; wpa_supplicant present | `disk-check-I1.txt` |
| I2 | Calamares UEFI GPT install | **PASS** ("Her şey tamam") | `I2/i-09-done.png` |
| I2 disk | same check | **PASS**, same facts as I1 (root `p2`, ESP `p1`) | `disk-check-I2.txt` |
| B1D | installed BIOS, CoW copy with a one-shot diagnostic unit (`diag-r20.sh`; test instrumentation on the copy only), greeter login with the test password | **PASS**: `id testuser`: `uid=1000(testuser) gid=1000(testuser)`, groups include wheel; `getent passwd live` and `getent group live` empty; `/` `0:0`; NetworkManager `active`; `systemd-networkd.service`, `.socket`, `-varlink.socket`, `-resolve-hook.socket` all `inactive`/`disabled`; systemd-resolved `active`; `nmcli`: `ens3:ethernet:connected:Kablolu bağlantı 1`; `resolvectl dns`: `Link 2 (ens3): 10.0.2.3`; `getent hosts kernel.org` resolves; `curl http://kernel.org/`: `HTTP/1.1 301 Moved Permanently`; `curl https://www.kernel.org/`: `HTTP/1.1 200 OK`; `wpa_supplicant v2.12`; 4677 firmware files; **0 failed units**. Journal errors: 2 kernel lines (`virt/tdx: TDX not supported`, `pcspkr already registered`), not from this change. Applet: the plasma-nm popup "Ağlar" lists "Kablolu bağlantı 1" under "Bağlı" | `diag-B1D.txt`, `B1D/B1D-desktop.png`, `B1D/B1D-applet.png` |
| U1D | installed UEFI, same method | **PASS**, same results (`enp0s2`), 0 failed units | `diag-U1D.txt`, `U1D/U1D-applet.png` |
| F1 | forced failure: BIOS live boot by QEMU direct kernel boot (ISO kernel and initramfs, the grub-iso.cfg arguments plus `alpbahos.testfail=live-cleanup`), install as I1 | **PASS (disk evidence)**: the install did not finish: on the target, the live-only items are still there (`/etc/calamares`, `/etc/polkit-1/rules.d/49-alpbahos-live.rules`, `/usr/lib/alpbahos/target-cleanup.sh`) and the MBR boot code is all zero, so the steps after `shellprocess@live-cleanup` (grubcfg, bootloader) did not run; the initramfs step before it did. The first user is `testuser:1000`. The error dialog itself was not captured in this run: the live session locked after about 5 idle minutes (see 4, item 1) | `disk-check-F1.txt`, `F1/f1-probe3.png` |
| F1b | the same forced failure again, with a Shift press every 30 s so the live session does not lock (harness `FAILRUN=1`) | **PASS**: Calamares shows "Hata — Kurulum Başarısız Oldu": `/bin/sh /usr/lib/alpbahos/target-cleanup.sh` ended with exit code 1; output: `alpbahos cleanup: TEST HOOK alpbahos.testfail=live-cleanup, removals skipped`, `alpbahos cleanup check FAILED: live-only file still present: /etc/polkit-1/rules.d/49-alpbahos-live.rules`, `... /usr/bin/alpbahos-install`, ... | `F1b/i-fail-7.png` |

## 4. Found during the tests (not fixed in this round)

1. **Live session locks and cannot be unlocked (blocker for the real-PC USB test).** After about 5 idle minutes the
   KDE screen locker locks the live session; the live user has no password (pam_unix without nullok), so the lock
   screen answers "Kilit açılamadı". A user who waits during an install on a real PC is locked out of the live
   session. Seen in F1 (`F1/f1-probe2.png`, `f1-probe3.png`). Proposed fix: no autolock and no lock on resume for the
   live user (`/home/live/.config/kscreenlockerrc`, live image only). BACKLOG LIVE-LOCK-01.
2. **Installed time zone and formats ignore D120.** The installed system has `/etc/localtime` ->
   `America/New_York` and `LC_TIME` (and the other `LC_*`) `en_US.utf8`; the panel clock shows `6:04 AM`. Our Calamares
   configuration has no `locale.conf` (Calamares defaults). BACKLOG LOCALE-DEFAULT-01.
3. **Harness:** on the first login of the installed system, Alt+Space then `konsole` opened System Settings instead
   of Konsole (B1, U1 screenshots), so the installed rows were done by the diagnostic unit (text, serial) instead of
   typing. The first `disk_check` in `r20-lanes.sh` used `lsblk` FSTYPE, which is empty for a new loop device; replaced
   by `disk-check-r20.sh` (blkid).
4. `mt7921s` (SDIO) and `mt7921-common` are in the live initramfs without firmware (dracut's choice). PCIe `mt7921e`
   is not. Not a problem for PCIe cards; noted for D150.

## 5. Not tested

- Real Wi-Fi hardware, real GPU firmware loading, and any real PC: not tested (the user's USB test, BETA-01).
- Wi-Fi in QEMU (no emulated Wi-Fi device): wpa_supplicant was not started by NetworkManager in any run.
- WPA3 (SAE) and OWE: built in, not exercised.
- L2 to L4, B2, B3, U2, FP, REC1, S1, R1 on r20: not run (the full matrix is the next step).
- PERF-01 RAM numbers: not measured on r20.
- `alpbahos.testfail=live-user` in a GUI install: only in the chroot test (case 3).
