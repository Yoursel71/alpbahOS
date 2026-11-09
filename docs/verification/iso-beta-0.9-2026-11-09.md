# AlpbahOS 0.9 Beta: beta round (2026-11-09), status and open items

Status: **NOT beta quality.** The ISO builds and the alp records are consistent (`alp check` rc 0). The live release
reaches the Plasma desktop on BIOS (PASS), but not on UEFI (FAIL; the alpha ISO fails the same way on this host, so this
round did not cause it). The installed-system QA and the install matrix were not run, and the shutdown crash fix is not
shown by a reproduction. Each item below says what was run and what was not.

Host: `thewo`, worktree `/home/yrslf/alpbahOS/wt-t2-kisayol`, branch `claude/t2-kisayol-2026-11-05`. Data in
`scratch-lfs-bench/` (not in the repo). Heavy work under `nice -n 19 ionice -c3`. The guest runs are TCG
(`-cpu qemu64`, no KVM). No real disk, host `/boot`, NVRAM, `/mnt/lfs`, `/mnt/hdd` or `lfs13-snapshots` was written.
The host was not rebooted.

## 0. Relabel (task 0): PASS

- The alpha ISO is `scratch-lfs-bench/images/alpbahos-alpha-2026-11-08.iso`, sha256 `d27f8803...5dc5d5`, checked with
  `sha256sum -c`. Its `.sha256` file name is fixed. It was not rebuilt.
- `docs/verification/iso-beta-2026-11-08.md` is now `docs/verification/iso-alpha-2026-11-08.md` (`git mv`), with a note
  at the top. References in `scripts/rebuild/r4/deltas/363.replace.sh` and `367.replace.sh` are updated.
- Branding: `/etc/os-release` and `/etc/lsb-release` say `AlpbahOS 0.9 Beta` (record `branding-r5fix`). Calamares
  `branding.desc` says `0.9 Beta`. The GRUB live menu says `AlpbahOS 0.9 Beta (live)`. All three were checked inside
  the release squashfs.

## 1. Build

| Item | Value |
|---|---|
| Release ISO | `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09.iso`, 4714883072 bytes |
| Release sha256 | `9d05c9c68d29767dcdafc7ed837de5ddb18164603a5b060811fca87def245a14` |
| DEBUG ISO (test only) | `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-debug.iso`, sha256 `459a0934b42920ec4e4d20007ffc28fba09e8d20639725f040e42f27099aaef2` |
| Build | `scripts/rebuild/iso/build-iso.sh` (release; `DEBUG=1` for the diagnostic image) |
| Source | `lfs13-snapshots/r4-iso-src-2026-11-09` (read-only snapshot of r4-root after the R5 records) |
| Checked in the release squashfs | `etc/os-release` = `AlpbahOS 0.9 Beta`; `etc/shadow`: `live::` (no password), `root:!x` (locked); `etc/pam.d/login`; `plasma-ksmserver`/`pipewire` stop-order drop-ins; `plasma-ksplash` SIGTERM status drop-in; sddm `User=live`; `usr/lib/alpbahos/live-medium-check` absent |

The DEBUG image differs from the release in three ways only: `rd.debug systemd.journald.forward_to_console=1` on the
kernel line (journal on the serial console), the live user has the password `live` (so a serial login works), and the
file name. It is a test image, not a release candidate.

## 2. Root causes and changes

Changes are alp records on r4-root (the state is in `scratch-lfs-bench/r4-ledger/r5/`; the scripts that produce them
are in `scripts/rebuild/r5/`):

| Record | Files | Change |
|---|---|---|
| `session-r5fix` 13.1-r5fix | 32 drop-ins and `/etc/pam.d/login` | user units stop before the session D-Bus bus and the compositor; `SuccessExitStatus=SIGTERM` for `plasma-ksplash.service`; book login PAM (missing before) |
| `autologin-r5fix` 13.1-r5fix | `/etc/pam.d/sddm-autologin` | the alpha stack (see 2.4) |
| `branding-r5fix` 0.9-r5fix | `/etc/os-release`, `/etc/lsb-release` | AlpbahOS 0.9 Beta |

Round 2 (this update): `/usr/lib/alpbahos/live-medium-check` removed from `session-r5fix` (`scripts/rebuild/r5/drop-live-medium-check.py`:
dropped from the record in the alp database under its lock, file deleted, `usr/lib/alpbahos` removed as empty).
`alp check` on r4-root: rc 0, 469 installed packages (`r4-ledger/r5/alp-check-r5c.txt`).

### 2.1 Session stop order (pipewire, plasma-ksmserver, plasma-kded6): drop-ins in place, crash fix NOT proven

- Evidence of the crash: the R5 BIOS boot of 2026-11-08 16:51 (`lfs13-logs/boot/r5/final3-journal-boot-1.txt`). The aborts
  happened at **shutdown**: `ksmserver` in libdbus (`dbus_pending_call_block`, `pending != NULL`), `kded6` after
  `Disconnected`, `pipewire` after `mod.x11-bell: X11 I/O error` on `:1` (the compositor's X server had gone).
- Cause (unit files and logout journal): the Plasma and pipewire user units had no ordering against `dbus.service` or
  the compositor, so the user manager stopped the bus in parallel with the clients.
- Test (round 1): two copies of the R5 image, `A-base5` (unchanged) and `B-fix5` (drop-ins); both had
  `/etc/pam.d/login` added so that the serial login works. 150 s Plasma session, then `systemctl --user exit`.
  Journals: `lfs13-logs/boot/sess/journal-A-logout.txt`, `journal-B-logout.txt`. In A the bus stops before ksmserver; in
  B ksmserver, kded6 and pipewire stop before the bus. **Neither run reproduced the abort on this path.**
- Round 2: the full-shutdown reproduction (task 5) was not run (see section 4).
- Not done: coredump backtraces (none on the R5 image; nothing reproduced).

### 2.2 plasma-ksplash "failed (signal)": fixed

- Every R5 session shows `plasma-ksplash.service: Main process exited, code=killed, status=15/TERM` and
  `Failed with result 'signal'`. The session stops the splash with SIGTERM, a normal stop. Fix:
  `SuccessExitStatus=SIGTERM` (drop-in in `session-r5fix`).

### 2.3 Console login: fixed (test copies verified)

- `/etc/pam.d/login` was missing in the R4 root. login(1) then refuses every login without asking for a password
  ("Giriş geçersiz" = Login incorrect, no `Parola:` prompt). Evidence: `lfs13-logs/boot/sess/A-base2/serial.log`.
  Fix: the book's login stack in `session-r5fix`. Serial login PASS on the test copies (`lfs13-logs/boot/sess/A-base5/`,
  `08:31:27 logged in on serial`).

### 2.4 Live autologin: UEFI NOT working (BIOS works); NOT a regression of this round

- Observed on every live boot of this round: sddm starts the autologin helper
  (`sddm-helper --start /usr/libexec/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland --user live --autologin`)
  about 44 to 48 s after boot. The helper is reported as `crashed (exit code 1)` and `exited with 9` within
  about 2 ms. No PAM or session message follows, and the greeter starts next. Exit code 9 with a crash status is a
  signal death (SIGKILL) in Qt's exit reporting. I did not find who sends it (no OOM, kernel or journal entry; see
  `lfs13-logs/boot/sess/DS2/serial.log`, `DS4/serial.log`, `DG/serial.log`).
- **The alpha ISO does the same in this environment.** The original `iso-test.sh` on the alpha ISO shows the greeter at
  135 s (`lfs13-logs/boot/iso-beta/alpha-orig-uefi/screen.png`). The same harness on the alpha ISO, no login, 300 s,
  shows the greeter at 300 s (`lfs13-logs/boot/sess/AS4/shot-end.ppm`). So this round did not break autologin. The
  alpha round's "autologin to desktop" notes are not reproduced on this host.
- **BIOS autologin works.** The release image on BIOS (`-machine pc`) reaches the Plasma desktop by 240 s
  (`RB3/shot-end.ppm`). So the failure is specific to the UEFI (q35/OVMF) boot in this environment, and the alpha UEFI
  shows it too. The UEFI cause is open.
- Changes checked against the alpha squashfs: `etc/sddm.conf` identical; sddm unit, helper binary, `system-*` PAM stacks
  identical; `etc/pam.d/sddm-autologin` differs only in comment lines (restored to the alpha stack in round 2); the live
  user has an empty password in the release (the alpha had `live:live`), and the DEBUG image (password `live`) fails
  the same way, so the password is not the cause; root is `!x` (locked) in the new image, `x` before.
- The earlier `pam_exec` / `pam_succeed_if` variant was removed (round 1, and it was not the cause).
- Open: find what kills the autologin helper (sddm `--debug` on a debug image, `strace`-like tracing of the helper, or a
  kernel/cgroup check). Open item 2.
- The live-only rule: the autologin User=live exists only in the live image (`build-iso.sh`, removed by
  `target-cleanup.sh`); the PAM stack is the alpha one (`pam_permit`). **Deviation:** no PAM-level live-medium check.
- Live credentials as built: the release live user has **no password** (`passwd -d live`); root is locked
  (`usermod -L root`). The greeter refuses an empty password (`pam_unix`, no `nullok`), so a release live user cannot log
  in at the greeter; only autologin, which does not work here, can start the desktop. The DEBUG image has `live:live`.

### 2.5 Boot time in the harness: the slowness was the test harness, fixed

- Round 1 boots took 110 s to reach `Hostname set` and then 30 s per systemd unit (no greeter after 300 s), on both the
  release and the alpha images, on a host with load 4 to 7.
- Cause: the serial console was a QEMU socket that the harness did not read while it slept. QEMU's chardev backpressure
  then blocked the guest's console writes (the kernel is `console=ttyS0`). The original `iso-test.sh` wrote the serial
  to a file, so it was not affected.
- Fix (`scripts/rebuild/image/session-test.py`): a reader thread drains the socket. `Hostname set` now comes at 16 s
  (`lfs13-logs/boot/sess/RU3`, `DS2`), and the release reaches the greeter (`RU3/shot-end.ppm`, 300 s). The image is not
  changed by this: it is a harness fix only.

## 3. Tests run

| Test | Result | Evidence |
|---|---|---|
| `pytest tests/test_r4_driver.py tests/test_audit_isa.py tests/test_r3_ledger.py` | 27 passed | terminal, round 1 |
| alp suite (`docs/handoffs/claude/alp-prototype`, `python3 -m pytest -q`) | 264 passed | terminal, round 1 |
| `check_docs.py` (`docs/handoffs/claude/tools/check_docs.py`) | 0 findings | terminal (re-run in round 2, see the commit) |
| `alp check` on r4-root (demo index) | rc 0, 469 packages | `r4-ledger/r5/alp-check-r5c.txt` |
| Release squashfs content | as in section 1 | `unsquashfs -cat` on the release ISO |
| Logout order (section 2.1) | drop-ins order the stops; no abort in A or B | `journal-A-logout.txt`, `journal-B-logout.txt` |
| Console login (section 2.3) | PASS on test copies | `A-base5/serial.log` |
| Live autologin, release and DEBUG, and alpha (section 2.4) | **FAIL** (all three) | `DS2`, `DS4`, `DG`, `RU3`, `AS4`, `alpha-orig-uefi` |
| Live release desktop, BIOS | **PASS** (desktop at 240 s, autologin) | `RB3/shot-end.ppm` |
| Live release desktop, UEFI | **FAIL** (greeter at 300 s; alpha same) | `RU3/shot-end.ppm`, `AS4/shot-end.ppm` |

## 4. QA of the installed system (task 3), install matrix (task 4), shutdown crash (task 5): NOT RUN

- The Calamares installer is started from the desktop launcher. The desktop needs autologin (section 2.4), and the
  greeter needs a password the release image does not have. The DEBUG image's greeter login (`live`) was not tried, so
  the installer could have been reached that way; it was not done in this round.
- So there is no installed image from this build. Not run: installed UEFI GPT and BIOS MSDOS, installed boots on
  virtio, ahci and NVMe, Konsole, Dolphin, System Settings, DHCP and `curl`, `wpctl` with `intel-hda`, Plasma menu
  shutdown and reboot, tr_TR and trq, and the shutdown reproduction 3 times with and without the drop-ins.
- Not claimed: no PASS for any item of 3, 4 or 5.

## 5. Release live screenshots

| Run | Firmware | Window | Screen at the end | Result |
|---|---|---|---|---|
| `RU3` | UEFI, release, no login | 300 s | greeter, user LIVE, password field (`RU3/shot-end.ppm`) | autologin not done |
| `RB3` | BIOS, release, no login | 240 s | **Plasma desktop**: taskbar, "Install AlpbahOS" launcher, welcome window, user session of `live` (`lfs13-logs/boot/sess/RB3/shot-end.ppm`) | **PASS** (live BIOS desktop by autologin) |
| `RU` / `RU2` | UEFI, release | 150 s / 330 s | round 1: boot still in systemd start (harness stall, section 2.5) | superseded by RU3 |
| `AS4` | UEFI, alpha, no login | 300 s | greeter (`AS4/shot-end.ppm`) | alpha: same |
| `alpha-orig-uefi` | UEFI, alpha, `iso-test.sh` | 135 s | greeter (`alpha-orig-uefi/screen.png`) | alpha: same |

All runs are TCG with `-cpu qemu64` (no KVM), on the same host. A KVM run was not made.

## 6. Deviations

- D-1 Live autologin does not work on the release, the DEBUG image, or the alpha, on this host (section 2.4).
- D-2 No PAM-level live-medium check; the live-only rule is the sddm configuration (section 2.4).
- D-3 The alpha `sddm-autologin` stack is kept; `pam_exec` and `pam_succeed_if` were tried and removed.
- D-4 Non-book sources, TOFU sha256 and the other R4 deviations (yaml-cpp, kpmcore, Calamares, libaio, lvm2, parted):
  unchanged from `iso-alpha-2026-11-08.md`.
- D-5 The config records have no upstream archive. The `source` of each record is the repository file (https URL),
  and its sha256 is the file's sha256. `adopt-base` requires an https URL.
- D-6 `/sources` is not in the image (as in R5).
- D-7 TCG only (`-cpu qemu64`). KVM was not used.

## 7. Open items

1. Shutdown crash: reproduce with a session and a full system shutdown on the installed image, 3 times, with and without
   the drop-ins; `coredumpctl` after the next boot. Not run in this round.
2. Live autologin: find what SIGKILLs the sddm autologin helper ~5 s after its start (section 2.4). The alpha has the same
   symptom here, so the old notes' PASS needs to be re-checked on this host.
3. Installed-system QA and the install matrix (section 4), including the Calamares path through the desktop.
4. The release live image has no way to a desktop without autologin (no password, greeter refuses).
5. RTKit (warnings only) and the system bus `Failed to drop supplementary groups` warning are not fixed.
6. Real hardware: not tested.
