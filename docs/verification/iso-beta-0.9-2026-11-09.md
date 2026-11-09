# AlpbahOS 0.9 Beta: beta round (2026-11-09), status and open items

Status: **NOT a beta release.** The ISO builds, the packages and the alp records are consistent, and the checks
below pass. The beta criteria are not met: the user-session crash fix is not proven, the live autologin failed on
the two DEBUG boots that were run with the current build, and the installed-system QA and the install matrix were
not run in this round. Each item says what was run and what was not.

Host: `thewo`, worktree `/home/yrslf/alpbahOS/wt-t2-kisayol`, branch `claude/t2-kisayol-2026-11-05`. Data in
`scratch-lfs-bench/` (not in the repo). Heavy work under `nice -n 19 ionice -c3`. No real disk, host `/boot`, NVRAM,
`/mnt/lfs`, `/mnt/hdd` or `lfs13-snapshots` (except the new read-only source snapshot of the ISO) was written.
The host was not rebooted. A short network outage of the host occurred during the run (no reboot, uptime kept).

## 0. Relabel (task 0)

- The alpha ISO is `scratch-lfs-bench/images/alpbahos-alpha-2026-11-08.iso` (sha256 `d27f8803...5dc5d5`, checked with
  `sha256sum -c`). Its `.sha256` file name is fixed. It was not rebuilt.
- `docs/verification/iso-beta-2026-11-08.md` is now `docs/verification/iso-alpha-2026-11-08.md` (`git mv`), with a note
  at the top. References in `scripts/rebuild/r4/deltas/363.replace.sh` and `367.replace.sh` are updated.
- Branding: `/etc/os-release` and `/etc/lsb-release` say `AlpbahOS 0.9 Beta` (record `branding-r5fix`, section 2).
  Calamares `branding.desc` says `0.9 Beta`. The GRUB live menu says `AlpbahOS 0.9 Beta (live)`.
  The R2 labels were still in the image before this round.

## 1. Build

| Item | Value |
|---|---|
| Release ISO | `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09.iso`, 4714883072 bytes |
| Release sha256 | `155eb5d866fd2a68a4136ec3913b242dc9e26f775968ea433df37e0a5681063d` |
| DEBUG ISO | `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-debug.iso`, sha256 `69b8e2122a7446323386f450db906dc5dcd2dc44858d2e29a295a6f7c74d7a1b` |
| Build | `scripts/rebuild/iso/build-iso.sh` (release, and `DEBUG=1` for the diagnostic image) |
| Source | `lfs13-snapshots/r4-iso-src-2026-11-09` (read-only snapshot of r4-root after the R5 records) |
| Checked in the squashfs | `etc/os-release` = `AlpbahOS 0.9 Beta`; `etc/shadow`: `live::` (no password), `root:!x` (locked); `etc/pam.d/login`; `etc/systemd/user/*.d/10-alpbahos-stop-order.conf`; `etc/systemd/user/plasma-ksplash.service.d/10-alpbahos-stop-status.conf`; sddm autologin `User=live` |

The DEBUG image differs from the release in three ways only: `rd.debug systemd.journald.forward_to_console=1` on the
kernel line (journal on the serial console), the live user has the password `live` (so a serial login works), and the
file name. It is a test image, not a release candidate.

## 2. Root causes and changes (task 1 and task 2)

Changes are alp records on r4-root (not in git; the scripts that produce them are in `scripts/rebuild/r5/`):

| Record | Files | Change |
|---|---|---|
| `session-r5fix` 13.1-r5fix | 32 drop-ins and helper files | `After=` ordering of user units against `dbus.service` and `plasma-kwin_wayland.service`; `SuccessExitStatus=SIGTERM` for `plasma-ksplash.service`; `/etc/pam.d/login` (see 2.3); helper `/usr/lib/alpbahos/live-medium-check` (present, not referenced, see 2.4) |
| `autologin-r5fix` 13.1-r5fix | `/etc/pam.d/sddm-autologin` | the alpha ISO stack (see 2.4) |
| `branding-r5fix` 0.9-r5fix | `/etc/os-release`, `/etc/lsb-release` | AlpbahOS 0.9 Beta |

`alp check` on r4-root: rc 0, 469 installed packages (`scratch-lfs-bench/r4-ledger/r5/alp-check-r5b.txt`).

### 2.1 Session stop order (pipewire, plasma-ksmserver, plasma-kded6)

- Evidence of the crashes: BIOS boot of the R5 image on 2026-11-08 16:51 (`lfs13-logs/boot/r5/final3-journal-boot-1.txt`).
  The crashes happened at **shutdown**, not during the session: `ksmserver` aborted in libdbus
  (`dbus_pending_call_block`, `pending != NULL`), `kded6` aborted after `Disconnected`, `pipewire` aborted after
  `mod.x11-bell: X11 I/O error` on display `:1` (the compositor's X server had gone).
- Root cause (from the unit files and the logout journal): the Plasma and pipewire user units had no ordering against
  `dbus.service` or the compositor. The user manager stopped the session bus in parallel with the clients, so the clients
  called D-Bus on a disconnected bus, and pipewire lost its X display first.
- Test: `session-test.py` on two copies of the R5 image (`lfs13-logs/boot/sess/A-base5` = unchanged,
  `B-fix5` = drop-ins; both copies had `/etc/pam.d/login` added so that the serial login works), 150 s Plasma session, then `systemctl --user exit`. Journals:
  `lfs13-logs/boot/sess/journal-A-logout.txt`, `journal-B-logout.txt`. In A the bus (`D-Bus User Message Bus`) stops
  before `KDE Session Management Server` (ksmserver). In B ksmserver, kded6 and pipewire stop before the bus.
  **Neither run reproduced the abort on this logout path** (no `dumped`, `ABRT` or assertion line in either journal).
  So the fix removes the ordering defect, but the crash itself was not reproduced without the fix and is not shown to be
  fixed. Open item 1.
- Not done: the coredump backtraces (none were on the R5 image; systemd-coredump had no files in it), and the RTKit
  warnings (`rtkit-daemon` is not installed; PipeWire and kwin fall back to normal priority; warnings only).

### 2.2 plasma-ksplash "failed (signal)"

- Every session in the R5 journals shows `plasma-ksplash.service: Main process exited, code=killed,
  status=15/TERM` followed by `Failed with result 'signal'`. The session stops the splash with SIGTERM, which is a normal stop.
- Fix: `SuccessExitStatus=SIGTERM` (drop-in in `session-r5fix`).

### 2.3 Console login (found in this round)

- `/etc/pam.d/login` was missing in the R4 root. login(1) then refuses every login without asking for a password
  ("Giriş geçersiz" = Login incorrect, no `Parola:` prompt). Evidence: `lfs13-logs/boot/sess/A-base2/serial.log`
  (and the image file list). The installed system could not log in on the console. Fix: the book's login stack
  in `session-r5fix`. Verified in the serial login of the test copies (`A-base5`, `B-fix5`).

### 2.4 Live autologin and PAM (task 2) — NOT resolved

- The implemented design (`session-r5fix`) added `pam_succeed_if user = live` and `pam_exec` (a live-medium check on the
  kernel argument `rd.live.image`) to `/etc/pam.d/sddm-autologin`. On the DEBUG live ISO, sddm then printed
  `Auth: sddm-helper exited with 9` at 44 s and the greeter came up. The autologin did not happen
  (`lfs13-logs/boot/sess/live-uefi-debug/serial.log`, `…/L2/serial.log`).
- The live-medium check itself returns 0 on the live system (`lfs13-logs/boot/sess/diag-live/guest-diag.txt`).
- `session-r5fix.py` also writes `/etc/pam.d/sddm-autologin` (the `pam_exec` variant). `autologin-r5fix` takes that file
  over in the same driver run (`scripts/rebuild/r5/apply-records.sh`), so the final file is the alpha stack.
- `autologin-r5fix` restores the alpha stack exactly. The autologin still failed on the next DEBUG boot with that stack
  (`…/L2/serial.log`). So the PAM edit is not the only cause. The sddm source (0.21.0) defines exit status 9 only through
  `HELPER_AUTH_ERROR` / `HELPER_SESSION_ERROR` / `HELPER_OTHER_ERROR`; the PAM error that failed is not in the journal.
- The alpha ISO's notes already record autologin failures on earlier builds with "no explanation". This is the same
  symptom. Open item 2.
- Live credentials as built: the release live user has **no password** (`passwd -d live`); root is locked (`usermod -L root`).
  The greeter login of the live user is refused by `pam_unix` (no `nullok`). The installer removes the live user and
  autologin from the target (`target-cleanup.sh`, unchanged). The DEBUG image uses password `live` (test image only).
- **Deviation:** the "PAM allows the live user only on the live medium" rule is not in PAM in this build. The autologin
  stack is the alpha stack (`pam_permit`); the restriction is the sddm configuration (`User=live` exists only in the live
  image, removed by `target-cleanup.sh`). `live-medium-check` is present in `session-r5fix` but not referenced.

## 3. Tests run

| Test | Result | Evidence |
|---|---|---|
| `pytest tests/test_r4_driver.py tests/test_audit_isa.py tests/test_r3_ledger.py` | 27 passed | (terminal output, this round) |
| alp suite (`docs/handoffs/claude/alp-prototype`, `python3 -m pytest -q`) | 264 passed | (terminal output, this round) |
| `check_docs.py` (`docs/handoffs/claude/tools/check_docs.py`) | 0 findings | (terminal output, this round) |
| `alp check` on r4-root (demo index) | rc 0, 469 packages | `r4-ledger/r5/alp-check-r5b.txt` |
| Squashfs content of the release ISO | as in section 1 | (`unsquashfs -cat`, this round) |
| Session logout test, UEFI, R5 image copies, unchanged (A) and drop-ins (B) | logout order fixed in B; no abort reproduced in A or B | section 2.1 |

## 4. QA of the installed system (task 3) and the install matrix (task 4)

Not run in this round. The Calamares installs were not driven (the installer is GUI-only and was not scripted), so there
is no installed disk image from this build. The matrix items below are open, with no PASS/FAIL claimed.

| Item | Status |
|---|---|
| Live UEFI, autologin to Plasma | **FAIL** on the DEBUG ISO (2 boots, sddm exit 9). Release ISO: see section 5 |
| Live BIOS, autologin to Plasma | release ISO: see section 5 |
| Installed UEFI GPT / BIOS MSDOS | not run |
| Installed boots, virtio / SATA ahci / NVMe | not run |
| QA: Konsole, Dolphin, System Settings, DHCP and `curl -I https://example.org`, `wpctl status` with intel-hda, shutdown/reboot from the Plasma menu, tr_TR and trq applied | not run |
| 0 coredumps over 3 boots with a 5-minute session | not met: no 5-minute session with autologin was reached in this round |

## 5. Release live screenshots

Release ISO has no serial login (live user has no password), so the test is screenshot only (`session-test.py`
with `NOLOGIN=1`): `lfs13-logs/boot/sess/RU/` (UEFI) and `lfs13-logs/boot/sess/RB/` (BIOS). See the result lines below.

| Run | Firmware | Window | Last state on the screen | Result |
|---|---|---|---|---|
| `RU` | UEFI, release | 150 s | systemd start (`Hostname set to <alpbahos>` at 110 s), text console only | inconclusive (no greeter, no desktop in the window) |
| `RB` | BIOS, release | 150 s | same stage (`Hostname set` at 110 s) | inconclusive |
| `RU2` | UEFI, release | 330 s (300 s shot) | still in systemd start at 300 s (`Queued start job for default target Graphical Interface` at 172 s; slice creation about 30 s apart) | inconclusive: no desktop in the window |

Host load during these runs was high (uptime load 4 to 7 on 16 cores, other workloads on the host), and the guest
clock showed `Watchdog remote CPU read timed out`. The boot was far slower than the alpha runs of 2026-11-08, so these
screens show no live desktop. No PASS is claimed for the live release. Images: `lfs13-logs/boot/sess/RU/shot-end.png`,
`RB/shot-end.png`, `RU2/shot-0300s.png` (the PNG files are generated from the PPM screendumps on the host).

## 6. Deviations

- D-1 Live autologin is not reproducibly working (section 2.4). The beta criteria are not met.
- D-2 The live-only restriction is in the sddm configuration, not in PAM (section 2.4).
- D-3 The alpha stack of `sddm-autologin` is kept; `pam_exec` and `pam_succeed_if` were tried and removed.
- D-4 Non-book sources, TOFU sha256 and the other R4 deviations (yaml-cpp, kpmcore, Calamares, libaio, lvm2, parted):
  unchanged from `iso-alpha-2026-11-08.md`.
- D-5 The config records have no upstream archive. The `source` of each record is the repository file (https URL), and
  its sha256 is the file's sha256. `adopt-base` requires an https URL.
- D-6 `/sources` is not in the image (as in R5).

## 7. Open items

1. Crash: the coredump-producing path (system shutdown with an active session, as on the R5 BIOS boot) is not reproduced
   with `systemctl --user exit`. Reproduce on a full system shutdown with a session, then read the coredumps.
2. Live autologin: sddm-helper exit 9 on the DEBUG ISO. Needs the PAM debug (`pam_debug` in the stack, or sddm
   `--debug`) on a debug image, then fix. Also check whether the alpha ISO autologs under the same harness.
3. Console login works in the test copies only (`/etc/pam.d/login` in `session-r5fix`); the release ISO has the record
   but was not booted to a console login.
4. Installed-system QA and the install matrix (section 4), including the Calamares install automation.
5. RTKit and the D-Bus `Failed to drop supplementary groups` warning (system bus) are not fixed.
6. The helper `live-medium-check` (in `session-r5fix`) is not used; remove it in the next record round.
7. Real hardware: not tested.
