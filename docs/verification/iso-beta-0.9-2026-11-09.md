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
| Release sha256 | `9d058d29767dcdafc7ed837de5ddb18164603a5b060811fca87def245a14` |
| DEBUG ISO (test only) | `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-debug.iso`, sha256 `459ab42920ec4e4d20007ffc28fba09e8d20639725f040e42f27099aaef2` |
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


## 8. Round 3 (2026-11-09, later): autologin lead, UEFI cause candidate, install and matrix status

Final release ISO (all matrix rows below name this sha unless stated):
`scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09.iso`, sha256 `5ae7e7c955700299f2c554a5d634b0a0330f93ab26bff7890a2976497b34c5cd`.
DEBUG ISO (test only): sha256 `6285f4848eeff676fb357c8557298166f509872b49df5935c0c6e7fa00b2`.
Accelerator for every guest in this round: TCG, `-cpu qemu64` (no KVM). Host: `thewo`, idle at the start of the run.

### 8.1 Lead check: the 3/3 UEFI PASS runs tested an earlier build

- `final-uefi-live-1..3` (`lfs13-logs/boot/iso-beta/`) ran at 22:29 to 22:38 on `alpbahos-beta-2026-11-08.iso`. That file
  was later overwritten by the build at 22:57 (the alpha ISO). So those runs do not test the alpha ISO.
- r4-root changes between 22:20 and 22:58 on 2026-11-08 (62 files): `parted` and `libparted` (row 372, built with
  device-mapper) and `ld.so.cache`. No sddm or PAM file changed in that window. The `live/` inputs changed at 07:xx and
  22:54 on the same day (`target-initramfs.sh`), which runs only at install time. The earlier ISO itself is gone, so the
  exact cause of the earlier PASS is not known.
- The alpha ISO fails the same way on this host (sections 2.4 and the correction in `iso-alpha-2026-11-08.md`).

### 8.2 Autologin: sddm helper and the UEFI display handover (root cause candidate, fix recorded)

- BIOS and UEFI differ in display bring-up. Under UEFI the kernel starts on `simpledrm` (efifb handover, `simple-framebuffer`
  at 2.3 s). The virtio-gpu DRM device (`virtio-pci 0000:00:01.0`, `virtio_gpu`) appears at about 31 s, after sddm has
  started (`systemd-logind: New seat seat0` at 27.9 s, sddm at 28.6 s). Under BIOS there is no simpledrm, and virtio-gpu
  is up at 29.9 s (`lfs13-logs/boot/sess/EB/serial.log`, `EU/serial.log`).
- The autologin helper is `sddm-helper --start plasma-dbus-run-session-if-needed startplasma-wayland --user live --autologin`.
  It is reported as `crashed` and `exited with 9` about 5 s after it starts (exit 9 = SIGKILL in Qt's exit reporting).
  The killer was not found; sddm 0.21 calls `terminate()` then `kill()` only in `Auth::stop()`, and the kill is not logged.
- Probes (`scripts/rebuild/image/autologin-probe.py`, serial to file, DEBUG images; decided from the serial log):

| Variant | Image (sha256 prefix) | UEFI results | BIOS results |
|---|---|---|---|
| base (no drop-in) | debug `459a`, round 2 | 0/3 success (fail at 57, 57, 72 s) | 2/2 success (108, 117 s) |
| v1: `After=systemd-udev-settle.service systemd-logind.service`, `ExecStartPre=udevadm settle --timeout=60` | debug-v1 (`scratch-lfs-bench/images`) | 3/3 success (63, 57, 57 s) | not run |
| v2: `ExecStartPre=/bin/sleep 20` | debug-v2 | 2/2 success so far (75, 75 s), third run incomplete | not run |

- Fix recorded: record `display-order-r5fix` 13.1-r5fix (alp, `scripts/rebuild/r5/display-order-r5fix.py`): sddm starts after
  udev has settled. Built into the final ISO. `alp check` rc 0, 470 packages (`r4-ledger/r5/alp-check-r5d.txt`).
- **The fix is NOT verified on the final ISO.** On the final release ISO, UEFI live boots show a black screen (no greeter,
  no desktop): `lfs13-logs/boot/final/rel-uefi-1..3/f170.ppm` (170 s) and `f400.ppm` (400 s), all three runs. The earlier
  UEFI release run (before the slideshow-text change, `final-rel-uefi-1` at 170 s) showed the desktop. So the UEFI live
  result is inconsistent between builds that differ only in `show.qml`, and it is not understood. The probe result (v1,
  3/3) was on a DEBUG variant with the drop-in added by overlay, not on the final release ISO.

### 8.3 Install and matrix status (what was run, what was not)

| Row | ISO sha (final unless noted) | Result | Evidence |
|---|---|---|---|
| Live release UEFI, desktop | 5ae7 | **FAIL**: black screen at 170 s and 400 s (3 runs) | `lfs13-logs/boot/final/rel-uefi-1..3/` |
| Live release BIOS, desktop | 5ae7 | **PASS** (the install VM reached the Plasma desktop and the Calamares window at 11:49, `lfs13-logs/boot/final/inst-bios/`) | `inst-bios/i-*.png`, `j1.png` |
| Calamares install BIOS MSDOS (virtio, vda, 30 GiB) | 5ae7 | **NOT COMPLETED**: installer driven by `scripts/rebuild/image/install-gui.sh` (locale tr_TR, keyboard Turkish, erase vda, users testuser, summary, install confirmed). At 12:00 the install was at about 8% (`unpackfs`), TCG, and the VM was at the Plasma lock screen. No bootloader yet (MBR zero at 12:00). | `inst-bios/k1.png`, `k2.png`, `k3.png`, `install-gui2.out` |
| Earlier BIOS install attempt | (round 3, first run) | discarded: stopped by my own QMP `quit` at 11:33 during `unpackfs` (the disk showed `grub.cfg` but no MBR) | `inst-bios` disk (overwritten) |
| Calamares install UEFI GPT | - | NOT RUN | - |
| Installed boots virtio / ahci / NVMe | - | NOT RUN | - |
| Installed-system QA (Konsole, Dolphin, System Settings, DHCP and curl, wpctl with intel-hda, Plasma shutdown and reboot, tr_TR and trq) | - | NOT RUN | - |
| Shutdown crash, 3 full shutdowns with a logged-in session, with and without the drop-ins, coredumpctl | - | NOT RUN | - |

- Items confirmed from the install screens of the final ISO: the slideshow reads "AlpbahOS 0.9 Beta" (the old "13.1 BETA"
  slideshow text is fixed in `calamares/branding/show.qml`); the summary shows `/dev/vda` (MSDOS) with one ext4 partition
  and the bootloader on `/dev/vda`; keyboard "Turkish / Ontanımlı" (Turkish-Q, the default variant of the `tr` layout). The
  console keymap written by the installer was `KEYMAP=trq` and `LANG=tr_TR.UTF-8` (checked on the partial install disk,
  `/etc/vconsole.conf` and `/etc/locale.conf`). `/etc/fstab` on that partial disk was still the live placeholder (the
  install had not reached the fstab step).

### 8.4 User report (not verified by the agent)

The project owner reports booting `alpbahos-alpha-2026-11-08.iso` from GRUB and says it works. Not known: machine,
firmware mode, autologin state, what was tested. Recorded as user-reported. It is not a full real-PC USB matrix pass
and not evidence that autologin works.

### 8.5 Status

NOT beta quality. The beta gate (autologin, live desktops, the install matrix and QA, all on the final sha) is not met:
UEFI live desktop fails on the final sha; the BIOS MSDOS install did not complete; the UEFI install, installed boots,
installed QA and the shutdown reproduction were not run. The autologin fix is recorded and probed on a variant but not
verified on the final release ISO.


## 9. Final matrix (round 4): release ISO sha256 `5ae7e7c955700299f2c554a5d634b0a0330f93ab26bff7890a2976497b34c5cd`

Every row tests this sha (the release ISO, `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09.iso`) unless the
row says otherwise. Accelerator: KVM with `-cpu qemu64` (ACCEL=kvm) except the rows marked TCG. The DEBUG ISO and the
variant ISOs were used only for the autologin probes (section 8) and are not part of the matrix. The ISO did not change
in round 4: the sha above is the same as in section 8.

### 9.1 Black screen (lead item 1): guest or capture?

- Under TCG, the UEFI release boots on this host (round 3) showed a black screen at 170 s and 400 s
  (`lfs13-logs/boot/final/rel-uefi-1..3/`). Under KVM the same sha reaches the desktop at 110 s with the welcome window
  (`lfs13-logs/boot/fix/uefi-kvm-1/g2.png`). Under TCG the same sha reaches the desktop at 300 s
  (`lfs13-logs/boot/tcg-final/uefi-live/t1.png`). The screen capture is faithful: the frames show the guest's boot text
  (round 3 `f170` shows the kernel log as it was), so the black frames are guest state during a slow boot, not a
  capture fault.
- Journal at the GRUB menu: `systemd.journald.forward_to_console=1` was added at the GRUB editor (no rebuild, the sha
  is unchanged). The forwarded journal on the serial console stops at `Reached target Graphical Interface` and the login
  prompt, so it does not show the session. Session state was checked from the desktop instead (taskbar, welcome window).
- Scanout: the guest logs `[drm] number of scanouts: 1` (one head). A `screendump` with a head index returned no file
  (not usable here), so the head comparison is inconclusive. The single scanout makes a second-head capture fault unlikely.
- Timing: the guest's virtio-gpu DRM device appears at 4 s under KVM and at 31 s under TCG (`fbcon: virtio_gpudrmfb is
  primary device`), after simpledrm. This is the handover described in section 8.2; the TCG black frames come from that
  slower handover under the 3-VM TCG load of round 3.
- Conclusion: a timing effect of the TCG guest under load, with the autologin fix (section 8) in place. Not a product
  fault shown on KVM. Not a capture fault.

### 9.2 Matrix

| # | Row | Accel | Result | Evidence (under `scratch-lfs-bench/lfs13-logs/boot/`) |
|---|---|---|---|---|
| M1 | Live UEFI, autologin to desktop (release, screen at 110 s) | KVM | **PASS** | `fix/uefi-kvm-1/g2.png` |
| M2 | Live UEFI, desktop (release, 300 s) | TCG (generic CPU proof) | **PASS** | `tcg-final/uefi-live/t1.png` |
| M3 | Live BIOS, autologin to desktop (release, 90 s) | KVM | **PASS** | `kvm/inst-bios/b0.png` |
| M4 | Live BIOS, desktop (release, 300 s) | TCG (generic CPU proof) | **PASS** | `tcg-final/bios-live/t2.png` |
| M5 | Calamares install, BIOS MSDOS, target virtio 30 GiB, erase vda, tr_TR, keyboard Turkish-Q, user testuser | KVM | **PASS** (install completed; unmount logged) | `kvm/inst-bios/i-*.png`, `k*.png`, `install-gui.out` |
| M5a | Installed disk after install: `/etc/fstab` has the root UUID; no `live` account; `grub.cfg` present; MBR has GRUB boot code | read-only loop mount of the disk | **PASS** | `kvm/inst-bios` (disk `scratch-lfs-bench/images/inst-bios-msdos-0.9.raw`), checked 12:44 and 13:02 |
| M6 | Calamares install, UEFI GPT, target virtio 30 GiB (EFI 512 MiB FAT32 /boot/efi, root ext4) | KVM | **PASS** (install completed; unmount logged) | `kvm/inst-uefi/u1..u4.png`, `serial.log` (unmount at 506 s) |
| M6a | Installed GPT disk after install: fstab has root and `/boot/efi`; no `live` account; `grub.cfg` (x86_64-efi); ESP `EFI/alpbahOS` and `EFI/BOOT/bootx64.efi` | read-only loop mount | **PASS** | `kvm/inst-uefi` (disk `inst-uefi-gpt-0.9.raw`) |
| M7 | Installed BIOS disk, boot on virtio, greeter login, desktop | KVM | **PASS** | `kvm/ib-virtio/s1.png` (greeter), `kvm/q-virtio/d1.png` (login), `kvm/q-virtio/qa1..qa5.png` |
| M8 | Installed BIOS disk, boot on AHCI (sata), login, network | KVM | **PASS** (login, `curl -sI example.org` HTTP/1.1 200, DHCP online 10.0.2.15) | `kvm/bios-ahci/ah2.png` |
| M9 | Installed BIOS disk, boot on NVMe | KVM | **FAIL**: SeaBIOS 1.17.0-10.fc44 prints `No bootable device` for the NVMe disk (also with `bootindex=1`), so this BIOS disk cannot be booted from NVMe in this QEMU | `kvm/bios-nvme/nv2.png`, `kvm/bios-nvme2/nv3.png` |
| M10 | Installed UEFI GPT disk, boot on virtio, greeter login, desktop | KVM | **PASS** (`hostnamectl`: AlpbahOS 0.9 Beta, firmware edk2, virtualization kvm; `ls /boot/efi/EFI`: alpbahOS, boot) | `kvm/uefi-disk-virtio/ue1.png`, `ue3.png` |
| M11 | Installed UEFI GPT disk, boot on NVMe, audio device (`intel-hda` + `hda-duplex`) | KVM | **PASS** for the boot and login; **FAIL** for sound: `wpctl status` lists only the dummy sink (`Temsili Çıkış`), and the Devices list is empty | `kvm/uefi-nvme/nu1.png` |
| M12 | Installed BIOS disk, boot on virtio, no audio device | KVM | (the sound check was not run on this row) | - |

Notes on the matrix:
- The BIOS installed disk was booted on AHCI with `sata` (ahci + ide-hd) and on virtio; it was not booted on NVMe (M9).
- The UEFI installed disk was booted on virtio (M10) and NVMe (M11). UEFI on AHCI was not run.
- Every installed boot above was run with `-cpu qemu64` under KVM. The two generic-CPU TCG proofs are M2 and M4.

### 9.3 Installed-system QA (BIOS installed disk, virtio, M7; KVM)

| Item | Result | Evidence |
|---|---|---|
| Konsole opens | **PASS** | `kvm/q-virtio/qa2.png` |
| Dolphin opens | **PASS** | `kvm/cyc2/m2.png` (Dolphin window) |
| System Settings opens | **PASS** | `kvm/q-virtio/qa1.png` |
| Network (DHCP) | **PASS** (networkctl: routable, online, 10.0.2.15 on ens3, gateway 10.0.2.2, DNS 10.0.2.3) | `kvm/q-virtio/qa4.png`; on AHCI `ah2.png` |
| `curl -sI` | **PASS** on AHCI (HTTP/1.1 200 OK from example.org). On the virtio disk the typed command was mangled by the keyboard mapping and was not rerun | `kvm/bios-ahci/ah2.png` |
| `wpctl status` with intel-hda | **FAIL**: only the dummy sink; no hardware sink or source (M11, UEFI NVMe). The BIOS virtio boot had no audio device | `kvm/uefi-nvme/nu1.png` |
| Plasma menu shutdown | **PASS** (Kickoff, Kapat, Şimdi Kapat; QEMU exited) | `kvm/cyc2/m3.png` |
| Plasma menu reboot | **PASS** (Kickoff, Yeniden Başlat, Şimdi Yeniden Başlat; QEMU exited, disk shows the next boot) | `kvm/cyc3/r1.png` |
| Locale tr_TR | **PASS** (`localectl status`: System Locale LANG=tr_TR.utf8) | `kvm/q-virtio/qa3.png` |
| Keyboard trq | **PASS** (`localectl status`: VC Keymap trq; X11 layout unset) | `kvm/q-virtio/qa3.png`; `/etc/vconsole.conf` KEYMAP=trq on the disk |
| Installed system identity | **PASS** (`hostnamectl`: AlpbahOS 0.9 Beta, kernel 7.1.8-alpbahos) | `kvm/q-virtio/qa3.png` |

Gap found: `ip` (iproute2) is not installed in the image (`bash: ip: command not found`). `networkctl` and `ifconfig`-type
checks work. Recorded as an open item.

### 9.4 Shutdown crash reproduction (installed BIOS disk, virtio, KVM, drop-ins present)

| Cycle | Action with a logged-in Plasma session | Result | Evidence |
|---|---|---|---|
| 1 | `systemctl poweroff` typed in Konsole (testuser, active session) | QEMU exited (powered off) | `kvm/cyc2` run, then `cyc2` boot |
| 2 | Kickoff, Kapat, Şimdi Kapat (Plasma menu shutdown) | QEMU exited | `kvm/cyc2/m3.png` |
| 3 | Kickoff, Yeniden Başlat, Şimdi Yeniden Başlat (Plasma menu restart) | QEMU exited (reset) | `kvm/cyc3/r1.png` |

Check after the cycles, on the disk image read-only as root (loop mount, `journalctl -D`, 5 boots in the journal):
- `/var/lib/systemd/coredump`: does not exist (no core dump was ever written).
- Journal lines matching `dumped|ABRT|pending != NULL|core-dump|Failed with result`: 0.
  The journal is `kvm/cyc3/journal-all.txt`. The `plasma-ksplash` SIGTERM stop is not reported as a failure
  (`Failed with result` count 0).
- `coredumpctl list` as `testuser` (the GUI user, not in `systemd-journal`) shows "No coredumps found" with the usual
  hint (`kvm/cyc3/c3a.png`); that view is limited to the user's own dumps, so the root check above is the real one.

Result: the shutdown crash did not reproduce in 3 full shutdowns with a logged-in session on the installed image with
the drop-ins. **Not proven as fixed**: the same test without the drop-ins (the baseline) was not run in round 4, so the
test does not show the drop-ins are what prevents it. The round-2 logout test (section 2.1) is still the only
comparison.

### 9.5 Gate

**Beta quality: NO.** The gate needs autologin, the live desktops, the install matrix and QA, all on the final sha.

- Live desktops: UEFI and BIOS, KVM and TCG: PASS (M1 to M4).
- Install matrix: BIOS MSDOS and UEFI GPT installs complete and their disks check out (M5, M5a, M6, M6a): PASS.
- Installed boots: BIOS virtio and AHCI, UEFI virtio and NVMe: PASS. BIOS NVMe: FAIL (M9, a SeaBIOS limit in this QEMU).
- QA: sound device not visible to pipewire (FAIL, M11); `ip` missing (gap); the rest PASS.
- Shutdown crash: 3 cycles, no crash found, not proven as fixed (no baseline without the drop-ins).

Open items:
1. Sound: the HDA device does not appear to pipewire in the guest. Check the kernel's `snd_hda_intel` module and the
   pipewire ALSA monitor in the guest with the device present at boot.
2. BIOS MSDOS disk on NVMe: not bootable under this SeaBIOS. Test NVMe with a UEFI install only (done: M11), or use
   another firmware build; not a product defect shown yet.
3. `ip` (iproute2) missing from the image.
4. Shutdown crash baseline without the drop-ins (3 cycles).
5. Autologin: the fix (section 8) is in the final ISO, but the UEFI autologin was not repeated 3 times on KVM on the final
   sha. The KVM run on the final sha reached the desktop once (M1). Repeat before any gate call.
6. The user-reported run of the alpha ISO (section 8.4) is unverified.


## 10. Round 5: sound fix, new ISO sha, final matrix (supersedes section 9 where they differ)

ISO: `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09.iso`, sha256 **`1686abfd38dc04fabbb405fdec85307d2a587160d18502a1f5b50f5cfe8d4347`**.
The previous release ISO (sha `5ae7`, section 9) is kept as `images/superseded-5ae7e7c9-release.iso` for reference.
Every matrix row below names this sha. Accelerator: KVM with `-cpu qemu64` (ACCEL=kvm) except rows marked TCG.

### 10.1 Sound: root cause and fix (lead item)

- Kernel config (`scratch-lfs-bench/r4-root` kernel `7.1.8-alpbahos`): `CONFIG_SND_HDA_INTEL=m`, `CONFIG_SND_HDA_CORE=m`,
  `CONFIG_SND_HDA_GENERIC=m` (the 7.x name; `CONFIG_SND_HDA_CODEC_GENERIC` does not exist in this kernel), Realtek and HDMI codecs `=m`.
  No kernel change is needed for the generic codec.
- Guest (installed UEFI disk, NVMe, `-device intel-hda -device hda-duplex`): `snd_hda_intel` and `snd_hda_codec` were loaded
  (`lsmod`), `/proc/asound/cards` said "no soundcards", `/dev/snd` had only `timer`, and wpctl listed only the dummy sink.
  The generic codec module was not loaded.
- Cause: the kernel's module helper path is `CONFIG_MODPROBE_PATH=/usr/bin/modprobe` (`cat /proc/sys/kernel/modprobe` in the
  guest). That file did not exist: kmod installs `/usr/bin/kmod` and links `/usr/sbin/modprobe -> ../bin/kmod`. So
  `request_module()` could not run the helper and the codec was never autoloaded. This is the autoload problem of
  USB-MODPROBE-01 in general, not sound-specific.
- Fix: record `modprobe-path-r5fix` 13.1-r5fix (alp, symlink `/usr/bin/modprobe -> kmod`, `scripts/rebuild/r5/modprobe-path-r5fix.py`).
  `alp check` on r4-root: rc 0, 471 installed packages (`r4-ledger/r5/alp-check-r5f.txt`). No kernel rebuild, so no kvm.ko or
  audit change. The ISO was rebuilt (new sha).
- Verified on the new sha: BIOS live (`bios-live-sound/s2.png`), installed BIOS (`inst-bios-boot1/q1.png`) and installed UEFI NVMe
  (`uefi-nvme-boot/un2.png`) show "Yerleşik Ses" (built-in audio) with an analog stereo sink and source. The tray volume icon is
  active where the earlier boots showed it muted.

### 10.2 `ip` and PATH

- `ip` is present: `/usr/sbin/ip` and `/sbin/ip` (`/sbin -> usr/sbin`). The earlier "ip: command not found" was a PATH
  effect for the GUI user's shell: `lsmod` and `ip` are in `/usr/sbin`, which the user's PATH does not contain.
- Round 6 comparison (item 3): the BLFS profile page, https://www.linuxfromscratch.org/blfs/view/stable/postlfs/profile.html (read on 2026-11-09 through a text fetch, so the wording is a summary of the page, not a byte copy), puts `pathappend /usr/sbin` only inside `if [ $EUID -eq 0 ]`. It does not add `/usr/sbin` to a normal user's PATH. `scratch-lfs-bench/r4-root/etc/profile` has the same structure: `export PATH=/usr/bin`, `/bin` prepended only if it is not a symlink, `/usr/sbin` and `/sbin` added only for EUID 0 (lines 30-36). So a GUI user's PATH without `/usr/sbin` is what the book's profile gives. No PATH change. Item closed: matches the book as fetched.
- Correction to section 9.3: "ip missing from the image" is wrong. Use `/usr/sbin/ip` or `networkctl` for now.

### 10.3 Matrix (sha 1686)

| # | Row | Accel | Result | Evidence (under `scratch-lfs-bench/lfs13-logs/boot/n2/`) |
|---|---|---|---|---|
| L1 | Live UEFI, autologin to desktop, 3 runs (taskbar pixel at 130 s, same colour as the desktop) | KVM | **PASS 3/3** | `uefi-live-1..3/a130.ppm` |
| L2 | Live UEFI, desktop at 300 s | TCG | **PASS** | `tcg-uefi-live/tt1.png` |
| L3 | Live BIOS, desktop with HDA device, sound visible | KVM | **PASS** (desktop; sound: `Yerleşik Ses`) | `bios-live-sound/s1.png`, `s2.png` |
| L4 | Live BIOS, desktop at 300 s | TCG | **PASS** | `tcg-bios-live/tb1.png` |
| I1 | Calamares install BIOS MSDOS, target virtio 30 GiB (erase vda, tr_TR, Turkish-Q, testuser) | KVM | **PASS** (installer completed; unmount logged) | `inst-bios/` (`install-gui.out`, `p1.png`) |
| I1a | BIOS disk after install: fstab root UUID; no `live` account; `grub.cfg` present; MBR GRUB code; VERSION 0.9 Beta | read-only loop mount | **PASS** | disk `inst-bios-msdos-0.9.raw` |
| I2 | Calamares install UEFI GPT, target virtio 30 GiB (EFI 512 MiB + ext4 root) | KVM | **PASS** (install completed) | `inst-uefi/u5.png`, `u6.png` |
| I2a | GPT disk after install: fstab root and /boot/efi; no `live` account; `grub.cfg` (x86_64-efi); ESP `EFI/alpbahOS`, `EFI/BOOT` | read-only loop mount | **PASS** | disk `inst-uefi-gpt-0.9.raw` |
| B1 | Installed BIOS, virtio: login, desktop, curl, networkctl, Konsole, Dolphin, System Settings, sound | KVM | **PASS** (sound `Yerleşik Ses` `q1.png`; curl `q2.png` HTTP 200; Dolphin `q3.png`; System Settings `q4.png`) | `inst-bios-boot1/` |
| B2 | Installed BIOS, AHCI: login, curl, networkctl | KVM | **PASS** (`bios-ahci/ah3.png`; sound not run on this row) | `bios-ahci/` |
| B3 | Installed BIOS, NVMe | KVM, SeaBIOS (pc), bootindex=0, -snapshot on the raw base | **PASS at -m 2G and -m 3G; FAIL at -m 4G and -m 6G.** At 2G: login, desktop, Konsole, `curl -I http://ftp.gnu.org` gives HTTP/1.1 200 OK (`r6/nvme-2g-curl/konsole-curl.png`); `ip` is not on the user PATH (10.2). At 4G and 6G SeaBIOS lists the NVMe disk and then prints `Boot failed: could not read the boot disk`. At 6G with a minimal device set (no VGA, xhci, NIC) it fails the same way, so the device set is not the cause. Without `bootindex` the NVMe is absent from the boot order and the guest prints `No bootable device` (`r6/b3-nobootindex/debugcon.log`). The earlier greeter boot (`nvme-fw/alp`) is reported by the coordinator as a 2G run; its command line was not saved. As far as these runs show, this is a SeaBIOS/QEMU setup effect tied to the RAM size, not a product fault. It says nothing about real machines with NVMe firmware. Evidence: `r6/nvme-mem/m2g-full`, `m3g-full`, `m4g-full`, `m6g-min` (debugcon). | - |
| U1 | Installed UEFI GPT, virtio: login, `hostnamectl` (AlpbahOS 0.9 Beta, kvm, edk2) | KVM | **PASS** | `uefi-virtio-boot/uv1.png` |
| U2 | Installed UEFI GPT, NVMe + intel-hda: login, sound (`Yerleşik Ses`), curl HTTP 200 | KVM | **PASS** | `uefi-nvme-boot/un1.png`, `un2.png` |
| S1 | Shutdown with a logged-in session, drop-ins present: 3 cycles (Konsole `systemctl poweroff`, each with 90 s session) | KVM | **3/3 completed**; disk journal: 0 matches for `dumped|ABRT|pending != NULL|core-dump|Failed with result`; no `/var/lib/systemd/coredump` | `inst-bios-boot1` run, `sd-cyc2`, `sd-cyc3`; journal `sd-journal-drop.txt` |
| S2 | Same 3 cycles on a copy with the drop-in files removed (baseline) | KVM | **3/3 completed**; 1 match: `at-spi-dbus-bus.service: Failed with result 'exit-code'` at logout (the session bus stopped first); no core dump | `inst-bios-nodropin-0.9.raw`, `nd-cyc1..3`; journal `nd-journal.txt` |

Autologin (lead item 1, on the final sha): L1 is 3/3 under KVM. The UEFI TCG run (L2) also reaches the desktop. The earlier
UEFI runs on the 5ae7 sha (section 9) were KVM once and TCG black frames under load.

### 10.4 Shutdown crash: status

- Drop-ins present: 3 logged-in shutdowns, no core dump, no abort, no at-spi stop failure.
- Drop-ins removed (baseline): 3 logged-in shutdowns, no core dump, but the at-spi failure appears.
- So the drop-ins remove a real stop-order failure (at-spi exits when the bus stops first). The original abort (ksmserver, kded6,
  pipewire core dumps, round 1) did **not** reproduce in either configuration on this path.
- Status: the stop-order fix is **proven for the at-spi failure**; the coredump crash is **not proven** (not reproduced without
  the fix, and the R5 logout test (section 2.1) was the only earlier comparison).

### 10.5 Gate

**Beta quality: NO.**

- Met: live desktops (UEFI and BIOS, KVM and TCG, on this sha); install matrix (BIOS MSDOS and UEFI GPT complete, disks check
  out); installed boots on BIOS virtio and AHCI, UEFI virtio and NVMe; sound (after the modprobe fix); login, network, curl,
  Konsole, Dolphin, System Settings, tr_TR, trq, shutdown and reboot from the Plasma menu (round 4, sha 5ae7; not rerun on
  1686 except the shutdown cycles and the items listed above).
- Not met: the coredump crash fix is not proven (section 10.4); the BIOS installed disk cannot boot on NVMe in this SeaBIOS
  (a firmware limit recorded as such, not a product FAIL, but the NVMe row is open for a firmware that can boot NVMe);
  the PATH question (10.2) is open.

Open items:
1. Coredump crash: find a reproducer that makes the baseline crash (ksmserver/kded6/pipewire aborts) on a shutdown.
2. PATH: closed in 10.2 (the book's profile does not put `/usr/sbin` in a user PATH; no change).
3. NVMe boot of the BIOS MSDOS disk: needs a firmware that boots NVMe (SeaBIOS here does not). UEFI NVMe is covered (U2).
4. Sound on the installed AHCI and virtio rows: sound was checked on BIOS virtio (B1) and UEFI NVMe (U2) only.
5. Real hardware: not tested.

### 10.6 Round 6 (2026-11-09, afternoon), sha 1686, KVM with `-cpu qemu64`

| Item | Result | Evidence |
|---|---|---|
| 1 (B3, NVMe boot and network) | done: boots and curl HTTP 200 at -m 2G and 3G; fails at 4G and 6G (SeaBIOS setup effect); row corrected (10.3) | `r6/b3-nobootindex/`, `r6/b3-net/`, `r6/b3-slot/` |
| 2 (shutdown coredump, Plasma menu, drop-ins vs baseline) | done: crash NOT reproduced on either set; not fixed (10.7). Six Plasma-menu shutdowns, KVM, 6G, virtio: drop-ins `sd/drop1..3` 3/3 and baseline (nodropin copy) `sd/base1..3` 3/3. No dump, abort, pending or `Failed with result` lines in the shutdown session, no `/var/lib/systemd/coredump`. |
| 3 (PATH) | done: comparison in 10.2, no change | `r4-root/etc/profile` |
| 4 (Plasma menu shutdown and reboot, tr_TR, trq, sound on AHCI) | done on sha 1686 (KVM): `localectl` gives LANG=tr_TR.utf8 and VC Keymap trq (X11 layout unset, so the Plasma X keymap was not checked); sound on installed AHCI: `Yerleşik Ses` analog stereo sink and source; Plasma menu Yeniden Başlat (reboot) returned to the SDDM greeter (SDDM layout shows `us`). Shutdown from the menu: row 2. Evidence: `r6/item4-ahci-reboot/`. |
| 5 (section 10 names) | done: `superseded-5ae7e7c9-release.iso` and `inst-bios-nodropin-0.9.raw` fixed. `images/inst-bios-nodropin-0.9.raw` deleted 2026-11-09 after item 2 (no other image deleted). |
| 6 (M12: alp update/rollback; live-ISO recovery) | 6a: partly done. `alp` has `update`, `upgrade` and `recover` (10.9); there is **no `rollback` subcommand**. On the installed overlay the catalog is absent (no `index.json`), so `update` and `upgrade` stop with "requires --index PATH"; not run further. 6b: **FAIL.** Live ISO plus overlay: grub config regenerated, but the initramfs regeneration (dracut) reported missing modules and the disk then fails to boot (`rescue.service` not found). Control (unchanged disk) boots to the desktop. Evidence: `r6/item6b-recovery/`, `r6/item6b-control/`. |
| 7 (CURRENT.md) | done | `CURRENT.md` |

Other facts found in round 6:
- `images/inst-bios-msdos-0.9.raw` has mtime 2026-11-09 15:26:57. Per the coordinator (D138) image files may be booted directly, and earlier rows did the same (mtime 14:54), so the mtime only shows the image has run since install. Overlays are used for new runs.
- Round 6 NVMe boots used `-snapshot` or overlays.

Gate: unchanged, **beta quality NO** (10.5). The real-PC USB test and the publication approval belong to the user.

### 10.7 Round 6 item 2: shutdown coredump, status

- Method: one overlay per run (`r6/sd/<name>/overlay.qcow2`, backing = the installed BIOS disk or the baseline copy), KVM, `-cpu qemu64`, virtio 6G, the shutdown-cycle flags, Konsole not used. Login on the greeter, 90 s session, Plasma menu (Kapat = Shut down). QEMU exited on its own after the guest powered off (16:02 to 16:22). Each overlay was read with `qemu-nbd -r`, mounted `ro,noload`: `r6/sd/<name>/check.txt` (matches and last lines) and `r6/sd/full-count.txt` (counts for the session boot).
- Drop-ins (`inst-bios-msdos-0.9.raw`): drop1, drop2, drop3 completed; 0 matches.
- Baseline (`inst-bios-nodropin-0.9.raw`, drop-ins removed): base1, base2, base3 completed; 0 matches in the session. The round 5 at-spi failure (`Failed with result 'exit-code'`) did not reappear.
- Not reproduced on either set. The stop-order fix is therefore not shown to matter for the coredump, and the crash fix is **NOT proven**. The drop1 check counted the session boot lines from 15:55 for the session; its dump search covered the whole journal.
- TCG shutdown runs: not run.
- Baseline image deleted after these runs (item 5).

### 10.8 Round 6 item 1 (B3) measurements

Memory size was the difference, not the device set (`r6/nvme-mem/`, debugcon, bootindex=0, `-snapshot` on the raw base, KVM):

| Run | RAM | Devices | Result |
|---|---|---|---|
| m2g-full | 2G | full (VGA, xhci, usb, NIC) | Boots (`Booting from 0000:7c00`); curl 200 (`nvme-2g-curl`) |
| m3g-full | 3G | full | Boots |
| m4g-full | 4G | full | `could not read the boot disk` |
| m6g-min | 6G | minimal (no VGA, xhci, NIC) | `could not read the boot disk` |
| (earlier) | 6G | full | `could not read the boot disk` (three runs) |

This is what these runs show: the NVMe read fails once RAM is 4G or more in this SeaBIOS/QEMU setup. It is a setup effect, not a product fault, and it says nothing about real machines with NVMe firmware.

### 10.9 Round 6 item 6: M12 checks

- 6a, alp (`docs/handoffs/claude/alp-prototype/alp.py`): commands are `search info install upgrade remove autoremove check list recover protect unprotect adopt-base update help`. There is no `rollback` command. Undo exists only inside a transaction (`FileJournal`, `undo_journal`, `ROLLBACK_DIR`) and `alp recover` replays an interrupted one. On the installed overlay (`r6/item6a-alp/`, Konsole) every command stopped with "--index PATH is required"; the installed system has no catalog `index.json` (checked read-only). So `alp update` and the rollback behaviour were **not run**. What is needed: a catalog on the installed system (or `--index` pointing at one), a harmless package in it, then `alp upgrade` to a newer version and a forced failure to exercise `recover`. No new function was built.
- 6b, recovery from the live ISO (BIOS, sha 1686; `r6/item6b-recovery/`):
  1. The live ISO booted with `-boot order=dc` (autologin). The installed overlay appeared as `vda`, root `vda1` (30 GiB).
  2. `sudo` is not installed in the live image; the live user has `pkexec` (polkit rule `polkit-49-alpbahos-live.rules`), which works without a password. `/usr/sbin/chroot` is needed because pkexec's PATH has no `/usr/sbin`.
  3. Mount `/dev/vda1` at `/mnt/inst`, bind dev, proc, sys; `grub-mkconfig` in the chroot: PASS (`Found linux image`, `Found initrd image: /boot/initramfs-7.1.8-alpbahos.img`, 6 menu entries).
  4. `dracut -f /boot/initramfs-7.1.8-alpbahos.img 7.1.8-alpbahos` in the chroot: **errors** `Module 'systemd-journald' depends on module 'systemd-sysusers', which can't be installed` and the same for `systemd-initrd`. The image file was rewritten (new timestamp, 26 MB).
  5. Quit the live VM and boot the overlay alone: GRUB loads the kernel and the new initramfs, then `systemd[1]: Failed to isolate default target: Unit rescue.service not found`, `Freezing execution` (`disk-boot`, screenshot `disk-desktop.png`). **FAIL.**
  6. Control (`r6/item6b-control/`): the unchanged installed disk, with no recovery steps, boots to the SDDM greeter and the Plasma desktop. So the disk itself is good; the recovery step (the dracut regeneration in this live setup) broke the boot.
  - Not established: whether a dracut run with the systemd-initrd modules present would fix it. The original initramfs was overwritten in the overlay, so the overlay cannot be reused as a clean control.
  - Overlay: a broken initramfs is in `r6/item6b-recovery/overlay.qcow2` only (not the installed disk).

## 11. Round 7 (2026-11-09, later): recovery, alp on an installed system, cosmetics

Scope of this section: the stages of the round 7 brief, in order. The ISO was **not rebuilt** and the final matrix was **not
rerun** (later round). Tests on images were host-side or in VMs on overlays of `images/`; no real disk, host `/boot`,
NVRAM, `/mnt/lfs` or `test-secrets` was touched.

### 11.1 Stage 1: recovery of an installed system (round 6 item 6b FAIL): PASS on both images (host-side recovery)

Root cause (found and reproduced, not guessed):
- The round 6 step ran `dracut -f /boot/initramfs-7.1.8-alpbahos.img 7.1.8-alpbahos` in the chroot. That call lacks the
  installer's options from `scripts/rebuild/iso/live/target-initramfs.sh`: `--no-hostonly` and the `--omit` list
  (systemd, systemd-initrd, dracut-systemd, systemd-journald, systemd-sysusers, ...). Without them dracut pulls in the
  systemd initrd modules; dependency errors print as `dracut[E]` lines, and dracut still exits **0**, so the step looked
  successful.
- Reproduced host-side on an overlay of `images/inst-bios-msdos-0.9.raw` (chroot of the target root, the target's own
  dracut 112): the manual call gives 3 `dracut[E]` lines (`systemd-journald` depends on `systemd-sysusers`; `systemd-initrd`
  and `dracut-systemd` follow). The image then has 109 `lsinitrd` lines matching `systemd` or `rescue`; the installer's image has 9
  lines matching `systemd` (its `lsinitrd` header shows `--no-hostonly --kver ... --omit ...`).
- Re-running the installer's own script in the same chroot gives rc 0, 0 `dracut[E]` lines, and the installer's image
  content.
- Round 6 VM evidence that the broken image fails: `r6/item6b-recovery/` (`disk-desktop.png`, "Unit rescue.service not found").
  The round 6 open question ("whether dracut with the systemd-initrd modules present would fix it") is answered by the
  next two rows, not by round 6.

Changes (repo, this commit):
- `scripts/rebuild/iso/live/target-initramfs.sh`: the dracut output is kept; `dracut[E]` in it now fails the step (dracut
  itself returns 0 in that case). The options are unchanged. Not yet exercised by an installer run: the next ISO round must.
- `scripts/rebuild/iso/live/alpbahos-recover.sh` (new): `/usr/local/sbin/alpbahos-recover ROOT_PART [ESP_PART]` on the live
  image. Mounts root (and ESP for UEFI) at `/mnt/alpbahos-recover`, binds dev, proc, sys, run; runs
  `target-initramfs.sh` in the chroot (the same initramfs as the installer); runs `grub-install` (BIOS:
  `--target=i386-pc DISK`; UEFI: `--target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=alpbahOS --removable
  --no-nvram`, so NVRAM is not written); runs `grub-mkconfig`; checks the kernel, the initramfs and the menu; unmounts on
  any exit. Without arguments it lists the partitions and changes nothing. Idempotent.
- `scripts/rebuild/iso/build-iso.sh`: installs the script as `/usr/local/sbin/alpbahos-recover` and checks it and
  `usr/lib/alpbahos/target-initramfs.sh` in the squashfs. The squashfs is also the installed system, so the script ends up
  on installed systems too. The ISO has not been rebuilt.

Tests (host-side, state: `scratch-lfs-bench/s1-recovery/`, not in the repo):

| image | steps | result | evidence |
|---|---|---|---|
| BIOS (`inst-bios-msdos-0.9.raw`, overlay, root `/dev/nbd0p1`) | manual dracut, then `alpbahos-recover /dev/nbd0p1` | recover rc 0; kernel 7.1.8-alpbahos, initramfs 42.6 MB, 1 menu entry | `s1-recovery/broken/manual-dracut.log`, `s1-recovery/broken/recover-run1.log` |
| BIOS, repaired overlay booted from disk alone | KVM, `-cpu qemu64`, virtio, 6G, login (test user, as round 6), Plasma desktop | **PASS** | `lfs13-logs/boot/r7/item1-bios-recover/` (`boot-greeter.png`, `desktop.png`) |
| UEFI (`inst-uefi-gpt-0.9.raw`, overlay, root `/dev/nbd1p2`, ESP `/dev/nbd1p1`) | manual dracut, then `alpbahos-recover /dev/nbd1p2 /dev/nbd1p1` | recover rc 0; `grub-install` x86_64-efi, removable fallback, no NVRAM | `s1-recovery/uefi-broken/manual-dracut.log`, `s1-recovery/uefi-broken/recover-run1.log` |
| UEFI, repaired overlay booted from disk alone (OVMF, no NVRAM entry: the fallback path boots) | KVM, login, Plasma desktop | **PASS** | `lfs13-logs/boot/r7/item1-uefi-recover/` (`boot-greeter.png`, `desktop.png`) |

Not run: the recovery from the live ISO itself (the script is not in any built ISO yet; the host-side run used the target's
own dracut and grub tools in a chroot of an overlay, which is the same tool set the live session chroot used in round 6).
Not run: a VM run of an unrepaired broken overlay (round 6 item6b-recovery already shows that failure). Not run: the
installer itself (Calamares) with the new `dracut[E]` check.

### 11.2 Stage 2: alp on an installed system: PASS (install, upgrade, remove, update, check, recover after kill -9); no rollback subcommand

Requirement, from the plan (not invented):
- `docs/MASTER_PLAN.md` M02 acceptance: "`alp install/remove/update/upgrade` pass on the test base with logs; rollback
  tested." §12: stable channel, user-started updates, "a system update must not leave libraries half-updated", "atomic
  system updates are not planned for the first release", fallback "still to be decided". §5.3 and §12 name no `alp rollback`
  command, and `docs/MASTER_PLAN.md` line 108 leaves open whether `update` and `upgrade` stay separate.
- Decision: the plan requires that rollback is **tested**, not a separate command. The rollback that exists is the journal
  undo (`FileJournal`, `undo_journal`, `ROLLBACK_DIR`, reached through `alp recover`). No `alp rollback` subcommand was built.
  The test below is the rollback test of an interrupted upgrade.

(a) Catalog location (decision and change):
- The installed system keeps its catalog at `<root>/usr/share/alp/index.json`, with the artifacts in `usr/share/alp/core/`
  (the index's own directory, as for the demo catalog). There was no config file or default lookup, so the smallest change
  was made: `resolve_index_path()` in `docs/handoffs/claude/alp-prototype/alp.py` uses that file when `--index` is absent
  (an explicit `--index` still wins; a missing default gives the error with the path). Tests: `tests/test_default_index.py`
  (3 new); the alp suite gives **267 passed** (264 before, all still pass).
- Not done: the image does not ship a catalog at that path yet, so an installed ISO still has no catalog. That needs the
  ISO round and a decision on which index the installed system ships.

(b) Install, upgrade, remove, update and check, on a copy of the BIOS installed disk (`images/inst-bios-msdos-0.9.raw`, an
overlay; root mounted on the host and used with `alp --root`, not in a booted VM). Test package `alp-r7-probe` (method
`core`, harmless text files under `usr/share/alp-r7-probe/`): v1.0.0 with 1 file, v1.0.1 with 3000 files.
- `alp list`, `alp --dry-run install`, `alp install alp-r7-probe`: 1.0.0 installed, rc 0.
- `alp check` with index v1.0.1: "güncelleme var: 1.0.0 -> 1.0.1", dependencies consistent (472 installed), rc 0.
- `alp --dry-run upgrade`: plan shown; `alp update` with no source refuses (needs `--source` or a `source` field: correct).
- `alp update --source catalog-v2.tar.gz` (a local bundle, no network): index replaced, `index.json.prev` kept, rc 0.
- `alp upgrade alp-r7-probe`: 1.0.1, 3000 files, rc 0. `alp remove alp-r7-probe`: files gone, not listed, rc 0.

(c) Forced failure mid-upgrade (`kill -9` of the `alp upgrade` process, 5 attempts at 0.6, 0.9, 1.2, 1.6, 2.0 s; reset to
v1.0.0 before each):
- 0.6 s and 0.9 s: killed while still at v1.0.0 (1 file). `alp recover` rc 0, state v1.0.0, check rc 0.
- **1.2 s: killed mid-transfer with 1518 of 3000 v1.0.1 files on disk** (`version.txt` still 1.0.0; the journal and
  `alp.lock` present). `alp recover` rc 0: back to v1.0.0 with exactly the v1 file set (1 file), `alp list` shows 1.0.0,
  `alp check` rc 0.
- 1.6 s: killed after all 3000 files and with `db.json.tmp` left: `alp recover` rc 0, back to v1.0.0, check rc 0.
- 2.0 s: the upgrade had finished before the kill (no process to kill): recover left v1.0.1 as it was, check rc 0.
- Then a clean `alp upgrade` (1.0.1, 3000 files, rc 0) and `alp remove` (rc 0, 0 files, not listed).
- Note: the script's label "MID-UPGRADE KILL CAUGHT" was printed after the recover step, so it is wrong for the 1.2 s
  case; the state before recover is in the `after kill -9` lines of the log.

Result: **PASS** for (a) with the change above, (b), and (c). The rollback requirement of M02 is met by the journal undo
(c), tested on the host against the overlay. Open items: the image does not ship a catalog; `alp` ran with the host's Python,
not inside the target; the same test has not run in a booted installed VM (round for the ISO).

Evidence (host, not in the repo): `scratch-lfs-bench/s2-alp/` (`catalog/`, `catalog-v2.tar.gz`, `killtest.sh`,
`killtest.log`, `kill-upgrade-*.out`, `kill-recover-*.out`, `kill-check-*.out`, `clean-*.out`).

### 11.3 Stage 3b: KDE "About this System" (record `kcm-about-r7fix` 0.9-r7fix): files verified, not shown on screen

- Keys, read from the installed KCM binary (`r4-root/usr/lib/plugins/plasma/kcms/kcm_about-distro.so`, strings): the
  config file is `kcm-about-distrorc`, group `[General]`, keys `LogoPath`, `Name`, `ShowBuild`, `UseOSReleaseVersion`,
  `Variant`, `Website`. There is **no `Version` key** (the brief named one): with `UseOSReleaseVersion=true` the version
  comes from `/etc/os-release` (`VERSION="0.9 Beta"`, record branding-r5fix). The record uses that.
- Record: `scripts/rebuild/r7/kcm-about-r7fix.py` (writes `etc/xdg/kcm-about-distrorc`, `usr/share/pixmaps/alpbahos-logo.png`,
  `usr/share/icons/hicolor/256x256/apps/alpbahos-logo.png`) and `scripts/rebuild/r7/apply-r7.sh` (the same steps as the R5
  driver: files, manifest, `r4_lib.py transfer`, `alp adopt-base`). The logo is `scripts/rebuild/iso/live/make-logo.py`
  output (256x256 RGB PNG, the AlpbahOS logo the installer uses); the hicolor icon cache is not regenerated.
- Result: `alp adopt-base` recorded "3 dosya, 0 symlink" (3 files); `alp check` **rc 0**, 472 installed packages (was 471).
  Evidence: `scratch-lfs-bench/r4-ledger/r7/kcm-about-r7fix/` (manifest, adopt.log, alp-check.txt).
- Not run: the KCM in a session (the "About this System" page with the logo). Deferred to the ISO round (VM check).
  The colours of the logo are the make-logo colours; the navy/cyan/orange check belongs to the fastfetch item (3a).

### 11.4 Stage 3c: SDDM login theme `alpbahos` (record `sddm-alpbahos-r7fix` 0.9-r7fix): recorded, not shown on a greeter

- Record: `scripts/rebuild/r7/sddm-alpbahos-r7fix.py` (run by `apply-r7.sh`). It copies the installed Breeze greeter
  (`/usr/share/sddm/themes/breeze`) as the starting point, keeps its QML and script files (copyright and SPDX headers
  unchanged), and replaces `metadata.desktop` (Name=AlpbahOS, Theme-Id=alpbahos), `theme.conf` (background and logo
  under `/usr/share/sddm/themes/alpbahos/`, `showlogo=shown`), and the images: `background.png` = the brand wallpaper
  `branding/alpbahos-brand/wallpaper/alpbahOS-Brand/contents/images/1920x1080.png`, `logo.png` = the make-logo PNG.
  `NOTICE` gives the Breeze licence (LGPL-2.0-or-later for the code).
- Config: `/etc/sddm.conf.d/alpbahos-theme.conf` with `[Theme] Current=alpbahos`. `/etc/sddm.conf` is not changed (its
  `[Autologin]` block for the live user stays). The round 4 display-order drop-in is in
  `/etc/systemd/system/sddm.service.d/` and is not touched.
- Turkish layout: the Breeze greeter already has the keyboard indicator (`KeyboardButton.qml`, `KeyboardIndicator` from
  Plasma), which shows the active layout (`trq` on the installed system, round 6 10.3). Nothing new was added for it.
- Result: `alp adopt-base` recorded 14 files; `alp check` **rc 0**, 473 installed packages (was 472).
  Evidence: `scratch-lfs-bench/r4-ledger/r7/sddm-alpbahos-r7fix/` (manifest, adopt.log, alp-check.txt).
- Licence note (open): the Breeze `metadata.desktop` has `License=CC-BY-SA` (copied as it is, the file is kept
  unchanged); the NOTICE gives LGPL-2.0-or-later for the code. The artwork licence of the Breeze files must be checked
  before publication.
- Fallback (not verified): the theme name is in `/etc/sddm.conf.d`; if the theme fails to load, the fallback behaviour
  was **not tested**. No QML tool (`qmlscene`, `qml`, `sddm-greeter --test-mode`) exists in r4-root, so no offline render
  was possible. **Deferred to the ISO round (VM check)**: the greeter must show the brand background and logo, and a login
  must reach the desktop.

## 12. Round 8 (2026-11-09, later): KDE About fix, fastfetch, image catalog, Flatpak

### 12.1 S1: KDE About Website value (record `kcm-about-r8fix` 0.9-r8fix): PASS

- Round 7 wrote `Website=https://github.com/alperenyardim30-hash/alpbahOS` (the origin repo, not a published page). Round 8
  removes the key. New record `scripts/rebuild/r8/kcm-about-r8fix.py` (run by `scripts/rebuild/r7/apply-r7.sh`) writes
  `etc/xdg/kcm-about-distrorc` without `Website`, the same logo, and takes the three paths over from kcm-about-r7fix
  (alp transfer, last writer owns). `alp check` rc 0, 474 packages. kcm-about-r7fix is now empty and protected as a base
  record (`alp remove` refuses), so it stays in the database with no files.
- Other values naming a repo (list, read on r4-root):
  - `usr/share/sddm/themes/alpbahos/metadata.desktop` `Website=https://github.com/sddm/sddm`: upstream SDDM project, copied
    from the Breeze metadata; not ours, left as is.
  - `etc/os-release` and `etc/lsb-release` (record branding-r5fix): no HOME_URL or website key; nothing to change.
  - `REPO_SRC` in the record scripts (`scripts/rebuild/r5/*.py`, `scripts/rebuild/r7/*.py`, `scripts/rebuild/r8/*.py`): the
    `source.url` that `alp adopt-base` requires for provenance. This is not a website value shown to users; left as is.
- Evidence: `scratch-lfs-bench/r4-ledger/r7/kcm-about-r8fix/` (manifest, adopt.log, alp-check.txt,
  alp-check-after-r7-removed.txt).

### 12.2 S2: fastfetch 2.71.0 with the AlpbahOS logo: PASS on the root (chroot); the greeter-free VM check is in the ISO round

- Source: upstream release **2.71.0** (newest stable on GitHub at the time, published 2026-11-06). Not in BLFS 13.1 (no
  fastfetch page or source in `blfs-src-13.1`), so the upstream tarball was used. Tarball
  `scratch-lfs-bench/r8/fastfetch/fastfetch-2.71.0.tar.gz`, size 2009867 bytes, **sha256
  160bfc7ece86541467a901577ce2fd2cfc2f4a2ad0b39d0d45f89c723dffcc51**.
- Build: `scripts/rebuild/r8/fastfetch-build.sh`, in a chroot of r4-root (`cmake`, `Unix Makefiles`, Release,
  `-march=x86-64 -mtune=generic`, `BUILD_TESTS=OFF`, `--parallel 16`: the standing C rule; the brief named -j8, a
  deviation), DESTDIR install into a staging tree, then the ISA audit of the staged files. Build logs:
  `scratch-lfs-bench/r8/fastfetch/fastfetch-{cmake,build,install}.log`. The build passed (rc 0).
- ISA audit: `scripts/lfs-blfs/cpu-baseline/audit-isa.sh` on the staged tree: 2 ELF files (`fastfetch`, `flashfetch`),
  0 non-variant AVX/BMI hits, rc 0 (`fastfetch/audit-isa.txt`).
- Records (alp): `fastfetch` 2.71.0 (43 files; `usr/share/fastfetch/presets/neofetch.jsonc` is left out: no neofetch
  preset) by `scripts/rebuild/r8/stage-record-r8.py` through `scripts/rebuild/r7/apply-r7.sh`; and
  `fastfetch-config-r8` 0.9-r8 (2 files: `/etc/fastfetch/config.jsonc`, `/usr/share/fastfetch/alpbahos-logo.txt`) by the
  same script with `REPLACE=1`, which takes over the files of the first config try (`fastfetch-config-r8fix`, empty now,
  protected base record; its first logo had a raw ESC byte in the JSON and fastfetch refused it, fixed in
  `scripts/rebuild/r8/fastfetch-logo-r8.py`).
- Logo and colours (`scripts/rebuild/r8/fastfetch-logo-r8.py`): the brand logo is a lighter diamond on a dark field
  (`make-logo.py`), so the terminal logo is a cyan (256-colour 51) diamond on a navy field (17, used as a background only),
  with an orange (208) centre; the title line "AlpbahOS 0.9 Beta" is orange. Navy is never used as text, so it stays
  readable on a dark terminal.
- Run: `chroot r4-root fastfetch --config /etc/fastfetch/config.jsonc --pipe false` (TERM=xterm-256color). Raw ANSI:
  `scratch-lfs-bench/r8/evidence/fastfetch-ansi.txt` (13847 bytes). Render: `evidence/fastfetch-render.png` (made with
  `scripts/rebuild/r8/ansi-render-r8.py`, PIL; it fills the block cells). Read and checked: diamond cyan, centre orange,
  navy field, title orange, OS line "AlpbahOS 0.9 Beta x86_64". The "Kernel" line shows the host kernel (the chroot shares
  it), so it is not the ISO kernel.
- Linkage: `ldd` in the chroot: libc, libm only.
- Result: `alp check` **rc 0**, 477 installed packages (was 472 at the start of S2, before S1's extra record and the
  fastfetch records). Not run: fastfetch on a booted installed system (ISO round, VM).
- Deviation: the R4 driver (`run-r4.sh`) builds only the BLFS 13.1 rows of `packages.tsv`. fastfetch is an upstream
  release, so it has a row in `packages.tsv` (`373`, class EXTRA, status r8) for the record, but it is built by its own
  script, not by the driver. No delta file was made.

### 12.3 S3: image catalog, hicolor icon cache, SDDM theme licence note: PASS on r4-root; installer and ISO not run

- **Catalog** (records `alp-catalog` 2026.11.09-r8, `scripts/rebuild/r8/make-catalog-r8.py`): `usr/share/alp/index.json`
  generated from the installed-package database (`var/lib/alp/db.json`): **470 entries** (status installed), 131779 bytes
  (about 0.13 MB on the ISO). Entry method is `lfs-base`, the method alp gives the adopted base packages, with version and
  the upstream source url and sha256 alp recorded. No `core/` directory is shipped (no artifacts: the base packages are
  files on the image). The catalog package itself is not listed; the database has 480 packages, the 10 others are the
  records with another status (empty protected records and the round 7/8 records that hold no files).
  - Checked on r4-root without `--index`: `alp search fastfetch` lists fastfetch and the config records; `alp info
    fastfetch` shows the record; `alp check` rc 0, 480 packages (`evidence/alp-check-no-index.txt`); `alp install
    fastfetch` says already installed; `alp install no-such-pkg-r8` is refused with "Bilinmeyen paket" and a hint.
  - Not done, and a limit: `_validate_catalog` (used by `alp update --source`) accepts only `recipe`, `core` and `flatpak`.
    So a remote catalog with `lfs-base` entries would be refused by `update`; the shipped catalog is not an update source.
    The installed packages cannot be installed from this catalog (no artifacts). Open: the catalog for installable
    packages is the job of the store round.
- **Hicolor icon cache** (record `hicolor-icon-cache-r8` 0.9-r8, `scripts/rebuild/r8/hicolor-cache-r8.sh`): the cache is
  regenerated with `gtk-update-icon-cache -f -t` on a copy of `usr/share/icons/hicolor` inside r4-root (chroot), so it
  includes the round 7 KDE About icon. The cache file (1724 bytes) took over from its base package (REPLACE, alp transfer).
- **SDDM theme licence** (record `sddm-notice-r8` 0.9-r8, text in `scripts/rebuild/r8/sddm-notice-r8.txt`): the round 7
  NOTICE said LGPL-2.0-or-later for everything. Read on the installed Breeze files: the QML files carry
  `SPDX-License-Identifier: LGPL-2.0-or-later` (4 files); `metadata.desktop` says `Author=KDE Visual Design Group`,
  `Copyright=(c) 2014, David Edmundson`, `License=CC-BY-SA`. No licence text ships on the system and no upstream licence
  file was found in `/usr/share/doc` or `/usr/share/licenses`. **Unsure** whether CC-BY-SA covers the artwork (faces/,
  images): the NOTICE says so and does not claim it. The metadata line is kept as Breeze has it.
- `alp check` rc 0 after the three records; the package count is 480 (was 477).
- Not run: the ISO build (the squashfs check now includes the catalog path only if added to build-iso.sh: not added in
  this round); the installer on a real disk. The catalog is a record on r4-root; the ISO round must carry it.

### 12.4 S4: Flatpak and Flathub: NOT STARTED (assessment only; clean stop, nothing recorded)

- Checked on r4-root (alp database): flatpak, bubblewrap, xdg-dbus-proxy, ostree, libxmlb, appstream, glib-networking,
  json-glib, libsoup, gpgme, libsecret, fuse3, libyaml, libseccomp: **none present**. p11-kit 0.26.5, libarchive 3.8.9
  and polkit are present.
- The R4 `packages.tsv` has no flatpak row (only `flatpak-kcm` in the Plasma list, commented out by the book). The
  scratch BLFS 13.1 source tree has no flatpak tarball. The BLFS plan file mentions it only for `flatpak-kcm`.
- So the chain is about 14 packages to build, with upstream sources not yet fetched and checked. That does not fit this
  run, so nothing was built and no record was made. alp check is unchanged (rc 0, 480 packages).
- Open for the next run: fetch the BLFS 13.1 flatpak page and its dependency list, add rows (with sha256) to
  `packages.tsv`, build bottom-up through the R4 driver, record each with alp, then `flatpak remote-add --system flathub`
  (remote file only), `/var/lib/flatpak` and the polkit rules. Verification in a chroot (`flatpak --version`,
  `flatpak remotes`) and the real `flatpak install` in a VM with network in the ISO round.

## 13. Round 9 (2026-11-09, later): real brand logo (D1), fastfetch colours (D2), Flatpak (F)

### 13.1 D1: the real brand logo replaces the placeholder diamond: PARTLY (fastfetch, KDE About, SDDM, Calamares done)

- Source: `docs/assets/alpbahOS-logo.png` (296x359 RGBA, opaque #141414 box). Keying as in
  `branding/alpbahos-brand/tools/build_brand_wallpaper.py` (distance <= 18 transparent, ramp to 30). Tool:
  `scripts/rebuild/r9/brand-logo-r9.py` (PNG at a height, or ANSI art with half-block characters and truecolour codes).
- **a. fastfetch** (record `fastfetch-logo-r9` 0.9-r9; logo file `usr/share/fastfetch/alpbahos-logo.txt`, 40 columns, 24
  rows of half-blocks): the mountain, the white prompt, the orange cursor and the two-tone wordmark bar are recognisable
  (render `scratch-lfs-bench/r9/evidence/fastfetch-logo-r9-render.png`, read and checked). **Honest:** at 40 columns the
  wordmark letters are not legible, and the navy mountain is low-contrast on a near-black terminal. No nearest-colour
  256 fallback was made (truecolour only). A 56-column variant would help the wordmark; not made this round.
- **b. KDE About** (record `kcm-about-r9fix` 0.9-r9): `LogoPath=/usr/share/pixmaps/alpbahos-logo.png` (unchanged key)
  now points at the brand icon `branding/icons/hicolor/256x256/apps/alpbahos.png`; hicolor sizes 32, 48, 64, 128, 256
  (`apps/alpbahos.png`) come from `branding/icons/hicolor`. The hicolor cache was regenerated (record
  `hicolor-icon-cache-r9` 0.9-r9). The KCM reads `LogoPath` as a file (checked in 11.3); the session view is not checked.
- **c. SDDM** (record `sddm-logo-r9` 0.9-r9): `usr/share/sddm/themes/alpbahos/logo.png` is the transparent brand logo at
  height 320 (264x320). The background is the brand wallpaper (unchanged). The greeter is not rendered (VM round).
  NOTICE corrected (record `sddm-notice-r9` 0.9-r9, text `scripts/rebuild/r9/sddm-notice-r9.txt`): the logo source is the
  real logo now, not `make-logo.py`.
- **d. Calamares / ISO build**: `scripts/rebuild/iso/build-iso.sh` installs `scripts/rebuild/iso/live/calamares/branding/logo.png`
  (the transparent brand logo, 320 px) as `/usr/share/calamares/branding/alpbahos/logo.png`; the placeholder generator
  `scripts/rebuild/iso/live/make-logo.py` is removed. `branding.desc` (productLogo, productIcon, productWelcome) and
  `show.qml` are unchanged. The ISO is not rebuilt.
- Where the placeholder was used (all replaced, round 9): fastfetch logo (round 8 diamond), KDE About pixmap and
  hicolor icon (round 8 diamond), SDDM logo (round 7 diamond), Calamares logo (`make-logo.py`). Remaining mentions of the
  old generator are in history text only (round 7/8 record scripts, `fastfetch-logo-r8.py` docstring, round 7 doc
  sections); those records are superseded and not in use.
- `alp check`: rc 0 after each record; the package count went 480 -> 486 with the six round 9 records of this section
  and 13.2 (fastfetch-logo-r9, kcm-about-r9fix, sddm-logo-r9, hicolor-icon-cache-r9, sddm-notice-r9, and 13.2's
  fastfetch-colour-r9).

### 13.2 D2: fastfetch key and separator colours (record `fastfetch-colour-r9` 0.9-r9): PASS on the dark render

- Config: `display.color` keys `1;36` (bold cyan), separator `1;37` (bold white); no navy foreground. Script
  `scripts/rebuild/r9/fastfetch-colour-r9.py`. Render `scratch-lfs-bench/r9/evidence/fastfetch-colour-r9-render.png`,
  read: the keys (OS, Kernel, Uptime, Shell, Terminal, CPU, Memory) are cyan and readable on the dark background; values
  white; the title orange. The renderer ignores bold, so the bold weight is not visible in the PNG. **Not checked:** a light
  terminal (cyan on white is weaker than on dark); the claim for light terminals is not verified.

### 13.3 F: Flatpak and Flathub: NOT STARTED (section 12.4 stands; next package: bubblewrap)

- Nothing from the 14-package chain was built or recorded in round 9. The dependency check of 12.4 is unchanged.
- The next package is **bubblewrap** (leaf; upstream source, sha256 to record); then xdg-dbus-proxy, libseccomp, libyaml,
  fuse3, json-glib, libsoup3, glib-networking, gpgme, libsecret, libxmlb, appstream, ostree, flatpak, in that order.
- Not done: flathub system remote, /var/lib/flatpak, polkit rules, `flatpak --version`, `flatpak remotes`.

### 13.4 Package count and root size

- `alp check` rc 0, **486 installed packages** (from 480 at the start of round 9). Root size delta: not measured (F is not
  done, so the round is not complete; the delta is reported when F is done).
- Untracked files in the worktree that are not from this round (`scripts/rebuild/iso/live/keyboard/`,
  `alpbahos-keyboard.desktop`, `keyboard-detect.cpp`) were left out of every commit.

## 14. Round 10 (2026-11-09, later): Flatpak chain (F), leaf first

Rules of this section: one package per row, build, ISA audit, alp record and commit; `alp check` rc 0 at each step;
generic x86-64 (`-march=x86-64 -mtune=generic`); -j16 for C, -j8 for heavy C++/Rust; downloads are the upstream release
tarballs (sha256 recorded); BLFS 13.1 versions where BLFS lists the package, otherwise newest stable upstream. Build
helper: `scripts/rebuild/r10/build-pkg-r10.sh` (chroot of r4-root, meson/cmake/configure, DESTDIR staging, audit-isa).
Records: `scripts/rebuild/r8/stage-record-r8.py` through `scripts/rebuild/r7/apply-r7.sh`. Evidence: `scratch-lfs-bench/r10/<name>/`
(tarball download in `r10/dl/`, `build.log`, `audit-isa.txt`).

### 14.1 bubblewrap 0.13.1: built, ISA audit rc 0, recorded

- Version: newest stable upstream (v0.13.1, published 2026-10-14). BLFS 13.1 does not list bubblewrap as a package (it
  appears only as an optional dependency of fontconfig in the book).
- Tarball `bubblewrap-0.13.1.tar.xz` from the GitHub release, 129472 bytes, **sha256 0e85c8702248b8dd64144f594147553650cdd0e4c951690345faace79c217c4d**.
- Build: meson, `-Dman=disabled -Dtests=false -Dselinux=disabled`, ninja -j16. Staged: 3 files (`usr/bin/bwrap`, bash and
  zsh completions). ISA audit of the one ELF file: rc 0.

### 14.2 xdg-dbus-proxy 0.1.9: built, ISA audit rc 0, recorded

- Version: newest stable upstream (GitHub release 0.1.9). Not a BLFS 13.1 package in the local copy (no BLFS page in the
  scratch cache; not checked against linuxfromscratch.org this round).
- Source: GitHub API tarball of tag 0.1.9, 57492 bytes, **sha256 7b77963c8da63c43d3fa173bae612b5fb306c81ff11f8307de7dc9430c2e92b7**.
- Build: meson `-Dman=disabled -Dtests=false`, ninja -j16, generic x86-64. Staged: 1 file (ELF), ISA audit rc 0.
- Record `xdg-dbus-proxy` 0.1.9 (alp). `alp check` rc 0, 488 packages. `packages.tsv` row 375.

### 14.3 libseccomp 2.6.1: built, ISA audit rc 0, recorded

- Version source: BLFS 13.1 `general/libseccomp.html` lists libseccomp-2.6.1. Tarball from the URL the book gives
  (`github.com/seccomp/libseccomp/releases/download/v2.6.1/libseccomp-2.6.1.tar.gz`), 656231 bytes, **sha256
  501f66c667225d53791b97e1d7cf85ab764c297d04881f60f38f451c4b0ee1be**. The release tarball carries configure (the API
  source tarball does not), so the release asset was used.
- Build: configure, `CFLAGS=-O2 -march=x86-64 -mtune=generic`, make -j16. Staged 45 files, 2 ELF, ISA audit rc 0.
- Record `libseccomp` 2.6.1 (alp). `alp check` rc 0, 489 packages. `packages.tsv` row 376.

### 14.4 libyaml: already present, not rebuilt

- r4-root already has libyaml 0.2.5 (alp record `yaml` 0.2.5, source `github.com/yaml/libyaml/releases/download/0.2.5/yaml-0.2.5.tar.gz`,
  sha256 c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4). BLFS 13.1 `general/libyaml.html` lists yaml-0.2.5:
  the same version, so nothing was built. `usr/lib/libyaml-0.so.2.0.9` and `usr/include/yaml.h` are present. No new row.

### 14.5 libassuan 3.0.2: built, ISA audit rc 0, recorded

- Version source: BLFS 13.1 `general/libassuan.html` lists libassuan-3.0.2 (URL `gnupg.org/ftp/gcrypt/libassuan/libassuan-3.0.2.tar.bz2`),
  593917 bytes, **sha256 d2931cdad266e633510f9970e1a2f346055e351bb19f9b78912475b8074c36f6**.
- Build: configure, generic x86-64, make -j16. Staged 9 files (8 recorded, `usr/share/info/dir` left out: install-info
  writes it and it belongs to the shared info index), 1 ELF, ISA audit rc 0.
- Record `libassuan` 3.0.2 (alp, 8 entries). `alp check` rc 0, 490 packages. `packages.tsv` row 377.
- Note on the first attempt: the record refused `usr/share/info/dir` after writing 7 files; those copies were removed
  (byte-identical to the stage, not the shared info/dir) and the record was repeated with that path excluded. The helper
  `scripts/rebuild/r11/pkg-url-r11.sh` now excludes it.

### 14.6 json-glib-1.10.8: built, recorded (round 12)
- Version source: BLFS 13.1 general/json-glib.html: 1.10.8; sha256 55c5c141a564245b8f8fbe7698663c87a45a7333c2a2c56f06f811ab73b212dd.
- Staged: staged files: 82; elf files: 3; audit-isa rc=0.
- Record: alp json-glib 1.10.8; alp check rc=0; packages 491; packages.tsv row 379.

### 14.7 libxmlb-0.3.29: built, recorded (round 12)
- Version source: BLFS 13.1 general/libxmlb.html: 0.3.29; sha256 448294be33bfae62f00fa66e506f1cae80237ce71b7ab6530aefa75005eeb08a.
- Staged: staged files: 28; elf files: 2; audit-isa rc=0.
- Record: alp libxmlb 0.3.29; alp check rc=0; packages 492; packages.tsv row 384.

### 14.8 glib-networking-2.90.1: built, recorded (round 12)
- Version source: upstream newest stable (not in BLFS 13.1 index): 2.90.1; sha256 ea95636590098355a05e3027579dba1a9a950b05e456b2488ea03d82e4b6c18a.
- Staged: staged files: 77; elf files: 1; audit-isa rc=0.
- Record: alp glib-networking 2.90.1; ; ; packages.tsv row 381.

### 14.9 nghttp2-1.70.0: built, recorded (round 12)
- Version source: BLFS 13.1 basicnet/nghttp2.html: 1.70.0 (dependency of libsoup3, built first); sha256 e05cb1388eaca3830aded4ccf20044b6e1ac1a61411dcca11b0437c4285c8bc2.
- Staged: staged files: 13; elf files: 1; audit-isa rc=0.
- Record: alp nghttp2 1.70.0; alp check rc=0; packages 494; packages.tsv row 388.

### 14.10 libsoup3-3.6.6: built, recorded (round 12)
- Version source: BLFS 13.1 basicnet/libsoup3.html: 3.6.6 (needs libnghttp2, row 388); sha256 51ed0ae06f9d5a40f401ff459e2e5f652f9a510b7730e1359ee66d14d4872740.
- Staged: staged files: 118; elf files: 1; audit-isa rc=0.
- Record: alp libsoup3 3.6.6; alp check rc=0; packages 495; packages.tsv row 380.

### 14.11 gpgme-2.1.2: built, recorded (round 12)
- Version source: BLFS 13.1 postlfs/gpgme.html: 2.1.2 (GPG_ERROR_CONFIG=gpgrt-config: libgpg-error 1.61 has no gpg-error-config); sha256 0687a95b299871c4141f507c0f740de6b429c9ac067d0fa4e062e3264df5fb77.
- Staged: staged files: 17; elf files: 4; audit-isa rc=0.
- Record: alp gpgme 2.1.2; alp check rc=0; packages 496; packages.tsv row 382.

### 14.12 ostree-2026.6: built, recorded (round 12)
- Version source: upstream newest stable (not in BLFS 13.1 index): v2026.6; sha256 164b8226aea6a0e6601036de02a5e3b62307bae25890ed557fb4e19020bd5974.
- Staged: staged files: 52; elf files: 6; audit-isa rc=0.
- Record: alp ostree 2026.6; alp check rc=0; packages 497; packages.tsv row 386.

### 14.13 fuse3-3.18.2: built, recorded (round 12)
- Version source: BLFS 13.1 postlfs/fuse.html: fuse-3.18.2; sha256 f01de85717e20adf5f98aff324acd85dd73d61a5ca3834d573dcf0bd6e54a298.
- Staged: staged files: 18; elf files: 3; audit-isa rc=0.
- Record: alp fuse3 3.18.2; ; ; packages.tsv row 378.

### 14.14 libsecret-0.21.7: built, recorded (round 12)
- Version source: BLFS 13.1 gnome/libsecret.html: 0.21.7; files taken over from kwallet 6.29.0; sha256 6b452e4750590a2b5617adc40026f28d2f4903de15f1250e1d1c40bfd68ed55e.
- Staged: staged files: 84; elf files: 2; audit-isa rc=0.
- Record: alp libsecret 0.21.7; alp check rc=0; packages 499; packages.tsv row 383.


### 14.16 libfyaml-0.9.6: built, recorded (round 12); first record failed the audit, re-recorded
- Version source: BLFS 13.1 general/libfyaml.html: 0.9.6 (dependency of appstream); sha256 a59cc3331e2eb903ec36933ad52a45888041cac31e44f553a00511131242c483.
- First record (500 packages): audit-isa rc=1, 207 nonvariant AVX/BMI hits, all in blake3_compress_subtree_wide (five static copies, one per blake3 backend: portable, sse2, sse41, avx2, avx512). Not -march=native: the flags were already -O2 -march=x86-64 -mtune=generic. The AVX2 and AVX512 copies come from upstream's per-backend objects (-mavx2, -mavx512f), and the name-based audit cannot see the runtime gate.
- Fix: upstream SIMD backends kept on (no portable-target switch). One exact entry (file usr/lib/libfyaml.so.0.0.0, symbol blake3_compress_subtree_wide) in scripts/lfs-blfs/cpu-baseline/audit-isa.allow, with the gate evidence: blake3_backend.c detected_backends_x86 sets AVX2 only with CPUID OSXSAVE, XCR0 bits 1-2 and CPUID.7 EBX bit 5, and AVX512 only with XCR0 bits 5-7 and CPUID.7 EBX bits 16 and 31; blake3_host_state.c intersects supported and detected backends. Rebuilt with the same generic flags and replaced the record (REPLACE=1 KEEP_SHARED=0).
- Result: audit-isa rc=0 (207 hits allowlisted, 0 unallowed; 37 staged files, 2 ELF). Runtime check: a test hashing 100000 bytes with the default, portable, sse2 and avx2 backends gives the same digest natively and under qemu-x86_64 -cpu qemu64 (no AVX), rc 0 both. appstreamcli --version prints 1.1.6 in the chroot.
- Record: alp libfyaml 0.9.6 (replaced); alp check rc=0; packages 506; packages.tsv row 389 (unchanged).

### 14.17 Flatpak chain status at the end of round 12: NOT complete (appstream blocked on itstool; flatpak not built)

- Recorded this round (10 packages, rows 378-389 without 387): fuse3 3.18.2, json-glib 1.10.8, libsoup3 3.6.6, glib-networking 2.90.1, gpgme 2.1.2, libsecret 0.21.7 (files taken over from kwallet 6.29.0), libxmlb 0.3.29, nghttp2 1.70.0 (dependency of libsoup3), ostree 2026.6, libfyaml 0.9.6 (dependency of appstream).
- appstream 1.1.6: build fails: `data/meson.build` needs `itstool` (program not found). itstool is not in r4-root; BLFS 13.1 lists it (not checked this round). Its runtime also needs the libxml2 Python bindings (not checked). This is the blocker; flatpak needs appstream (hard dependency in meson 1.18.4).
- flatpak 1.18.4: not built (needs appstream). No flathub remote, no /var/lib/flatpak, no polkit rules, `flatpak --version` not run.
- Root size: `du -sx r4-root` before 115782688 KiB, after 115830500 KiB (+47812 KiB). Package count 500; `alp check` rc 0.
- Next package: itstool (BLFS 13.1 version to be looked up), then appstream 1.1.6 (with -Dgir=false etc.; the step script passes them), then flatpak 1.18.4 (GitHub release tarball).

### 14.18 lxml-6.1.1: built, recorded (round 12)
- Version source: BLFS 13.1 general/python-modules.html#lxml: 6.1.1 (pip3 wheel --no-build-isolation --no-deps, installed into a staging root); needed by the itstool 2.0.7 lxml patch. sha256 ba96ae44888e0185281e937633a743ea90d5a196c6000f82565ebb0580012d40 (md5 6bbd3674ecba1340b08c9180afef1829, as in BLFS).
- Helper: scripts/rebuild/r10/build-pkg-r10.sh gained the kinds autogen and pip and the PRE_PATCH variable (existing kinds unchanged).
- Staged: staged files: 125; elf files: 7; audit-isa rc=0.
- Record: alp lxml 6.1.1; alp check rc=0; packages 501; packages.tsv row 390.

### 14.19 itstool-2.0.7: built, recorded (round 12)
- Version source: BLFS 13.1 pst/itstool.html: 2.0.7 with its patch itstool-2.0.7-lxml-1.patch (sha256 035a0d22bd1cf37a00357ebc096454e1eb8594f3ea54f8122e8e76fdced0cbec): lxml replaces the libxml2 Python bindings, which BLFS calls deprecated and which libxml2 2.15.3 leaves disabled by default. sha256 fba78a37dc3535e4686c7f57407b97d03c676e3a57beac5fb2315162b0cc3176 (md5 e759b258617a912acce630de3fa43957, as in BLFS).
- Staged: staged files: 8; elf files: 0; audit-isa rc=2 (no ELF files, nothing to audit). Chroot check: itstool --version prints 2.0.7 and a test .pot extraction works; the itstool test suite was not run.
- Record: alp itstool 2.0.7; alp check rc=0; packages 502; packages.tsv row 391.

### 14.20 appstream-1.1.6: built, recorded (round 12)
- Version source: BLFS 13.1 general/appstream.html: 1.1.6. sha256 e298929f39729e84a70f6be6941f3e7f3fc2ee3c83cb3ea1b1b5b280a8fe3a24.
- Options: BLFS -Dapidocs=false -Dbash-completion=false -Dstemming=false, plus -Dgir=false -Dvapi=false -Dqt=false -Dsystemd=false -Dcompose=false -Dapt-support=false -Ddocs=false -Dman=false (docbook-xsl-ns is not in the root). The -Dtests=false of the failed attempt is not an option in 1.1.6 and was dropped.
- Staged: staged files: 164; elf files: 2; audit-isa rc=0.
- Record: alp appstream 1.1.6; alp check rc=0; packages 503; packages.tsv row 392.

### 14.21 pyparsing-3.3.2: built, recorded (round 12)
- Version source: BLFS 13.1 general/python-modules.html#pyparsing: 3.3.2 (pip3 wheel, pure Python; the flatpak meson setup stops without it). sha256 c777f4d763f140633dcb6d8a3eda953bf7a214dc4eff598413c070bcdc117cbc (md5 ca3bea68cd1a84584b68cd7bed679464, as in BLFS).
- Staged: staged files: 43; elf files: 0; audit-isa rc=2 (no ELF files, nothing to audit).
- Record: alp pyparsing 3.3.2; alp check rc=0; packages 504; packages.tsv row 394.

### 14.22 flatpak-1.18.4: built, recorded (round 12)
- Version source: upstream newest stable (not in BLFS 13.1 index): 1.18.4, GitHub release tarball. sha256 b899a7a00c48d2c626cb8ec33fe556720b376c25805d7222430c0fdca4c6ac8d.
- Options: -Dsystem_bubblewrap=/usr/bin/bwrap -Dsystem_dbus_proxy=/usr/bin/xdg-dbus-proxy -Dsystem_helper=enabled -Dsystem_install_dir=/var/lib/flatpak -Dsystemd=disabled -Ddconf=disabled -Dmalcontent=disabled -Dgir=disabled -Dgtkdoc=disabled -Dxauth=disabled -Dwayland_security_context=disabled -Dselinux_module=disabled -Ddocbook_docs=disabled -Dman=disabled -Dtests=false.
- Staged: staged files: 84; elf files: 8; audit-isa rc=0. Chroot: flatpak --version prints Flatpak 1.18.4.
- Record: alp flatpak 1.18.4; alp check rc=0; packages 505; packages.tsv row 393.

### 14.23 flathub remote definition: config only (round 12)
- Source: https://dl.flathub.org/repo/flathub.flatpakrepo (Url=https://dl.flathub.org/repo/), sha256 3371dd250e61d9e1633630073fefda153cd4426f72f4afa0c3373ae2e8fea03a; installed as /etc/flatpak/remotes.d/flathub.flatpakrepo. No remote-add, no repo summary, no app, no repo data.
- Staged: 1 file, no ELF. Chroot `flatpak remotes` prints nothing: the remote is not listed until the system repo (/var/lib/flatpak/repo) exists, which was not created here.
- Record: alp flathub-remote 1 (config only); alp check rc=0; packages 506; packages.tsv row 395.

### 14.24 Flatpak chain status at the end of round 12: flatpak built
- Built and recorded in this run: lxml 6.1.1 (needed by itstool), itstool 2.0.7, appstream 1.1.6, pyparsing 3.3.2 (needed by the flatpak meson setup), flatpak 1.18.4, and the flathub remote config record. Rows 390-395; rows 385 and 387 stay unused.
- `flatpak --version`: Flatpak 1.18.4. `flatpak remotes` in the chroot: empty (see 14.23). Package count 506; alp check rc=0.
- Root size: `sudo du -sx r4-root` 115856704 KiB; 14.17 recorded 115830500 KiB before this run (+26204 KiB).
- Open items: libfyaml-0.9.6 was re-recorded with the audit fix (14.16): audit-isa rc=0. Appstream and flatpak test suites were not run; flatpak runtime (sandbox, remote listing, app install) was not tested, by design. Flatpak is built without systemd, dconf, malcontent, gir, gtkdoc, xauth, Wayland security context, SELinux module, and man pages/docs.

## 15. Round 13 (2026-11-09, later): ISO r13, full matrix on the new sha, new checks

### 15.1 Stage 1: build and content check

- ISO: `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-r13.iso`, sha256 **`03469d2900c1cc77a28d06fe6b7a22ec83d15df744cc0228cef75842c7e2ba7b`**, 4738207744 bytes (4.5 GiB). `.sha256` file written by the script. This sha differs from the previous release (`1686abfd...`, section 10) and from `5ae7e7c9...` (section 9).
- The build used `TAG=r13`: the release name `alpbahos-beta-0.9-2026-11-09.iso` is taken by the previous release (kept, not overwritten; the build script refuses existing names). No DEBUG. The script itself was not changed.
- Source snapshot: the old `lfs13-snapshots/r4-iso-src-2026-11-09` (taken 17:58, before the flatpak build at 18:35) was renamed to `r4-iso-src-2026-11-09-prev-r12` (kept, not deleted), and the build made a new read-only snapshot of `r4-root`. The writable copy `iso-work/live-root` was removed by the script; the empty `iso-work/` directory was removed after the checks.
- Build log: `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/build/build-r13.log` (plus `10-dracut.log`, `20-mksquashfs.log`, `40-xorriso.log`, `50-el-torito.log` in the same directory). Squashfs listing (read-only loop mount of the ISO): `scratch-lfs-bench/iso-check-r13.lls` (230094 entries).
- Required paths, checked in the ISO squashfs: all present: `usr/local/sbin/alpbahos-recover`, `usr/lib/alpbahos/target-initramfs.sh`, `usr/share/alp/index.json`, `usr/bin/fastfetch`, `etc/fastfetch/config.jsonc`, `usr/share/sddm/themes/alpbahos`, `etc/sddm.conf.d/alpbahos-theme.conf`, `etc/xdg/kcm-about-distrorc`, `usr/bin/flatpak`, `etc/flatpak/remotes.d/flathub.flatpakrepo`, `usr/share/calamares/branding/alpbahos/logo.png`. Nothing missing.
- Calamares logo: the squashfs `logo.png` has sha256 `647ff0e8...ae71`, the same as the repo file `scripts/rebuild/iso/live/calamares/branding/logo.png` and the SDDM theme logo in r4-root. So the Calamares and SDDM logos are the real brand logo (not the placeholder).
- `alp check` on r4-root: rc 0, 506 installed packages (`scratch-lfs-bench/alp-check-r13.txt`).
- Stage 1 commit: this section only (no code change).

### 15.2 Matrix on sha `03469d29...` (ISO r13)

All rows name ISO `alpbahos-beta-0.9-2026-11-09-r13.iso`, sha256 `03469d2900c1cc77a28d06fe6b7a22ec83d15df744cc0228cef75842c7e2ba7b`. Evidence paths are under `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r13/`. Every screenshot named here was opened and read by the agent. Installed-system rows boot the read-only base image with `-snapshot` (QEMU discards its writes); S1 uses a qcow2 overlay and REC1/REC2 use a reflink copy of the installed image (see 15.4 item 10). "NOT VERIFIED" means the row ran but its check did not produce the evidence the brief asks for.

| Row | Run | Accel | Result | Evidence |
|---|---|---|---|---|
| L1 | live UEFI, desktop at 130 s, 3 runs | KVM, qemu64 | **PASS 3/3** (taskbar, Install icon, wallpaper, Welcome Center window) | `L1-1/shot-130.png`, `L1-2/`, `L1-3/` |
| L2 | live UEFI, desktop at 300 s | TCG | **PASS** | `L2/shot-300.png` |
| L3 | live BIOS, desktop at 130 s with HDA device | KVM | **PASS** (desktop; sound not checked on the live row) | `L3/shot-130.png` |
| L4 | live BIOS, desktop at 300 s | TCG | **PASS** | `L4/shot-300.png` |
| I1 | Calamares BIOS MSDOS, 30 GiB raw, erase vda, tr_TR, Turkish-Q, testuser | KVM | **PASS** (completion page: "Her şey tamam", AlpbahOS 0.9 Beta installed) | `I1/i-09-done.png`; image `images/inst-bios-msdos-0.9b.raw` |
| I1a | BIOS disk, read-only loop mount | none | **PASS**: fstab root UUID 7ff179a0-... equals blkid; no live account; testuser present; grub.cfg present; MBR has GRUB code; VERSION 0.9 Beta | this section (read-only check output) |
| I2 | Calamares UEFI GPT, 30 GiB raw, erase vda, same user | KVM | **PASS** (completion page) | `I2/i-09-done.png`; image `images/inst-uefi-gpt-0.9b.raw` |
| I2a | GPT disk, read-only loop mount | none | **PASS**: fstab root ddfaae53-... and /boot/efi 480B-DAFF equal blkid; no live account; grub.cfg; ESP has EFI/alpbahOS/grubx64.efi and EFI/boot/bootx64.efi; hostname alpbahos-test; VERSION 0.9 Beta | this section |
| B1 | installed BIOS, virtio: login, desktop, Konsole, Dolphin, System Settings, sound | KVM | **PASS** login, desktop, Konsole, Dolphin, System Settings; sound "Yerleşik Ses Analog Stereo" (sink and source) PASS; **curl NOT VERIFIED** (15.4 item 3) | `B1/`, `B1b/`, `B1c/`, `B1d/` |
| B2 | installed BIOS, AHCI: login, desktop | KVM | **PASS** login and desktop; **curl NOT VERIFIED**; sound not run | `B2/B2-desktop.png`, `B2/B2-curl.png` |
| B3 | installed BIOS, NVMe, -m 2G, bootindex 0 | KVM, SeaBIOS (pc) | **PASS** login and desktop; **curl NOT VERIFIED** | `B3/B3-desktop.png`, `B3/B3-curl.png` |
| U1 | installed UEFI, virtio: login, hostnamectl, failed units, fusermount3 | KVM, OVMF | **PASS** login, hostnamectl (AlpbahOS 0.9 Beta, kvm, edk2), systemctl --failed (0 loaded units); **curl NOT VERIFIED**; Flatpak in this run not reached (screen locked, see 15.4 item 1) | `U1/U1-hostnamectl.png`, `U1/U1-failed.png`, `U1/U1-fusermount.png` |
| U1c | same UEFI image, fresh snapshot: idle lock off, Flatpak remote, install, About | KVM, OVMF | **Flatpak FAIL** (remote-add GPG error; install not run); **About this System PASS** | `U1c/U1c-remote-add.png`, `U1c/U1c-install-done.png`, `U1c/U1c-about.png` |
| U2 | installed UEFI, NVMe + intel-hda: login, sound, lsblk | KVM, OVMF | **PASS** login, sound, lsblk (nvme0n1: p1 512M /boot/efi, p2 29.5G /); **curl NOT VERIFIED** | `U2/U2-desktop.png`, `U2/U2-wpctl.png`, `U2/U2-lsblk.png` |
| S1 | 3 shutdown cycles on a qcow2 overlay of the BIOS image; Konsole `systemctl poweroff` (deviation: not the Plasma Kapat menu); session about 60 s | KVM | **PASS 3/3**: each cycle ended with the guest powered off; the overlay's journal has 3 poweroff entries and 0 matches for dumped, ABRT, pending != NULL, core-dump, Failed with result; /var/lib/systemd/coredump is empty | `S1-c1..c3/`, `S1-c*/s1-c*-session.png`; overlay `ov-s1.qcow2` |
| R1 | reboot from Konsole (deviation: not the Plasma menu) | KVM | **PASS**: the SDDM greeter returns after the reboot | `R1/R1-after-reboot.png` |
| T1 | locale and keymap | KVM | **PASS** for LANG=tr_TR.utf8 and VC Keymap trq; X11 Layout is unset (15.4 item 8) | `B1d/B1d-localectl.png` |
| REC1 | BIOS recovery from the live ISO: broken disk copy (initramfs removed, grub.cfg truncated) as /dev/vda | KVM | **PASS**: alpbahos-recover listed the partitions, ran steps 1 to 6 and printed "recovery done; unmounting; reboot the installed disk"; the repaired disk boots to the SDDM greeter | `REC1c/rec1c-step0-list.png`, `REC1c/rec1c-step1.png`, `REC1c-boot/rec1c-disk-greeter.png` |
| REC2 | UEFI GPT recovery, same procedure | KVM | **PASS**: same six steps (ESP and root); the repaired disk boots to the greeter | `REC2/rec2-step0-list.png`, `REC2/rec2-step1.png`, `REC2-boot/rec2-disk-greeter.png` |
| FP | Flatpak: remote, install one app, run | KVM | **FAIL** (15.4 item 1) | `U1c/` |

Notes on the matrix:
- REC1 and U1 first runs failed for test-harness reasons and were rerun. REC1 booted the broken disk before the ISO (fixed with `-boot order=dc`), and the live `alpbahos-recover` is not on the user PATH, so the calls use `/usr/local/sbin/alpbahos-recover`. U1 locked and blanked the screen after about 10 minutes idle, so its flatpak commands were typed into the lock screen; U1c turns the lock off first.
- Install I1 was driven by `drv-install.sh` and I2 by `drv-install2.sh` (scripts in the r13 directory). The first I1 attempt typed the password and hostname with keys that the installer session does not map as intended, and Next stayed disabled; the fields were retyped by hand and the install then ran. I2 needed a second click on Install because the first click landed above the button. Both final screens show the completion page.
- The sha 03469d29 is a new build from r4-root (it contains the round 8 to 12 records, including the flatpak chain built after the old snapshot). It differs in bytes from the release sha 1686abfd and from 5ae7e7c9.

### 15.3 New visible checks

- (a) SDDM greeter with the alpbahos theme: **NOT CONFIRMED.** /etc/sddm.conf.d/alpbahos-theme.conf on the installed disk sets Current=alpbahos and the theme directory is present. The greeter shows the theme layout (top bar with session, keyboard and power; blue background; user card; clock). The brand logo was not visible on any login frame. The theme's Main.qml sets the logo opacity to 0 while the login UI is shown (loginScreenRoot.uiVisible), so the logo is expected to be hidden on that frame. Not shown on screen; open.
- (b) System Settings, About this System (Sistem Hakkında, U1c): **PASS.** It shows "AlpbahOS 0.9 Beta" with the mountain logo, KDE Plasma 6.7.4, Qt 6.11.2, kernel 7.1.8-alpbahos, Wayland, llvmpipe.
- (c) fastfetch in Konsole (B1): **PASS.** The AlpbahOS logo is drawn; the title line is "AlpbahOS 0.9 Beta" with orange key names and white values; the colours are readable. The screen shows OS AlpbahOS 0.9 Beta x86_64, Kernel linux 7.1.8-alpbahos, Window Manager KWin (Wayland).
- (d) alp with no --index (B1, screens b1-alp-list.png, b1-alp-search.png, b1-alp-check.png): **FAIL.** alp list, alp search fastfetch and alp check each print "alp: hata: Bu komut için --index PATH gereklidir." (needs --index PATH). No sudo is needed: they fail before reading the catalog. Cause in 15.4 item 2.

### 15.4 Failures, open items and explanations

1. **Flatpak FAIL (first real run).** pkexec flatpak remote-add --if-not-exists flathub /etc/flatpak/remotes.d/flathub.flatpakrepo shows the polkit dialog for testuser (wheel group), accepts the password, then prints `error: GPG: Unable to configure context: gpgme_ctx_set_engine_info: GPGME: Geçersiz kripto işletkisi` (invalid crypto engine). flatpak run org.gnome.Calculator then reports that app/org.gnome.Calculator/x86_64/master is not installed. Best explanation: GnuPG is missing from the image. r4-root has gpgme-config, gpgme-tool, gpgme-json and gpg-error, but no gpg or gpgconf, so gpgme has no engine to use. Not fixed in this round: a fix changes the build inputs, so it needs a new record, a new ISO and a full rerun.
2. **alp FAIL on the installed system.** The installed /usr/lib/alp/alp.py (r4-root, 3007 lines) is an older copy. The repo file docs/handoffs/claude/alp-prototype/alp.py (3019 lines, commit 711d699, round 7 "alp default catalog path") makes usr/share/alp/index.json the default, and the r4-root copy does not have that code (diff 18 lines). The catalog file itself is on the installed disk (/usr/share/alp/index.json, 131779 bytes). The "alp check rc 0" gate ran the repo copy, so it did not show this. Fix: install the repo alp.py into r4-root through alp (new record), rebuild, and rerun the rows that use alp.
3. **curl NOT VERIFIED.** In every guest session (B1d, B2, B3, U1, U2) the command `curl -I ftp.gnu.org` was echoed and a new prompt came back with no output, not even an error (also with -sS). The r4-root curl 8.21.0 runs (in the chroot it reports "Could not resolve host", because the chroot has no DNS). The round 6 PASS (HTTP/1.1 200, sha 1686) is not repeated on this sha. Cause not found; it is not claimed as a PASS.
4. **sudo.** The installed system has no sudo ("bash: sudo: command not found"). pkexec with the testuser password works (the polkit dialog appears). The brief's sudo path was not available.
5. **fusermount3 mode (review item 1).** The file in r4-root and on the installed disk is -rwxr-xr-x (755), not setuid. The brief says the record has 4755; the r4-ledger record was not compared field by field, so the difference is between the brief and the file. The BLFS stable book (fuse page, postlfs/fuse.html, Fuse 3.17.4) installs fusermount3 and then runs chmod u+s /usr/bin/fusermount3. The text here is from a search summary, not a verbatim quote; the source is https://www.linuxfromscratch.org/blfs/view/stable/postlfs/fuse.html. So the book's setuid bit is missing in this image, and unprivileged FUSE mounts would fail. Not changed in this round.
6. **Failed units (review item 2).** On the installed UEFI disk (U1), systemctl --failed lists 0 loaded units. dmesg and the journal were not read for flatpak or fuse3 messages beyond that.
7. **target-initramfs.sh noise.** In REC1 and REC2 step 3 prints "echo: write error: Veri alınamıyor" twice (line 33: echo "$LIST" | grep -q ...). grep -q exits at the first match and closes the pipe, so the echo fails. The checks themselves pass and the recovery continues. Harmless, but noisy. Not changed.
8. **Keyboard (open; not worked on; see docs/verification/user-feedback-keyboard-2026-11-09.md).** On the installed system localectl shows VC Keymap trq but X11 Layout (unset). The Plasma session types as US (the minus and dot keys need the US mapping there), and the SDDM greeter shows the tr layout on some boots and us on others. The installer chose Turkish, but the desktop the user works in is US. This matches the user's feedback. The cause is not analysed here.
9. **Shutdown crash.** S1 does not reproduce the coredump crash (3 cycles, 0 dumps). It is still not proven fixed.
10. **Deviations.** S1 and R1 used Konsole systemctl poweroff/reboot instead of the Plasma Kapat/restart menu; S1 sessions were about 60 s, not 90 s. Installed-system rows used -snapshot on the read-only base instead of overlays. REC1 and REC2 broke a reflink copy of the installed image, not a qcow2 overlay (no qemu-nbd was used). The B3 row used the NVMe device with SeaBIOS at -m 2G, as the brief asks.

### 15.5 Not run

- Flatpak: the Calculator app was never installed or started (remote-add failed).
- Shutdown and reboot from the Plasma menu (Kapat): not run; Konsole was used.
- A 90 s logged-in session in each S1 cycle.
- Sound on B2 and B3 (AHCI and NVMe).
- The SDDM logo on a login frame: not shown.
- dmesg and journal review for flatpak and fuse3 messages (only systemctl --failed).
- A curl PASS on this sha (15.4 item 3).
- The real-PC USB test and the publication decision: the user's, not part of the QEMU gate.

### 15.6 Gate (QEMU level, sha 03469d29)

**NOT MET.** Passing: live UEFI and BIOS desktops (KVM and TCG); both installs with clean disk checks; installed boots (BIOS virtio, AHCI, NVMe at 2G; UEFI virtio and NVMe); sound on B1 and U2; shutdown 3/3 with no dumps; reboot back to the greeter; tr_TR and trq locale and keymap settings; both recoveries with the repaired disks booting; About this System; fastfetch. Failing: Flatpak (GPG engine missing), alp without --index (old alp.py in r4-root), curl NOT VERIFIED on every installed row, fusermount3 not setuid against the book, SDDM logo not shown. Still open: the keyboard layout result (15.4 item 8), the coredump crash (not reproduced, not proven fixed), the real-PC USB test and the publication approval (the user's).

## 16. Round 14 (2026-11-09, later): fixes for items 1-6, ISO r14, matrix on the new sha

ISO: `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-r14.iso`, sha256 **`ae1ef2d8f1b91380958f2a9a3055b5c50abbc50a111d9234d39393c93100e4ce`**, 4742668288 bytes. Built with `TAG=r14` (build script unchanged). Contents checked read-only in the squashfs: `usr/bin/fusermount3` mode 4755 (`-rwsr-xr-x`), `etc/xdg/kxkbrc`, `usr/lib/alp/alp.py` identical to the repo file, `usr/share/sddm/themes/alpbahos/Main.qml` with the logo patch, `usr/bin/gpg` and `gpgconf`, `usr/bin/flatpak`, `usr/local/sbin/alpbahos-recover`, `usr/share/alp/index.json`. The r13 snapshot was renamed to `r4-iso-src-2026-11-09-prev-r13` (kept).

### 16.1 Item 1: Flatpak, GnuPG (commit 1fadc0f)

- Recorded through alp with `pkg-url-r11.sh` (BLFS 13.1 stable versions, `postlfs/gnupg.html`): npth 1.8 (sha256 `8bd24b4f...`), libksba 1.8.0 (`296b9db9...`), gnupg 2.5.21 (`e3af2c8c...`). Rows 397, 398, 396 in packages.tsv (two rows first written as 394 and 395 and renumbered, because those numbers were in use). `alp check` rc 0 after each step (509 packages).
- Evidence in r4-root: `gpg --version` = GnuPG 2.5.21, libgcrypt 1.12.2; `gpgconf --list-dirs` works.
- Result: **remote configured, PASS.** `flatpak remotes` lists `flathub system`. `pkexec flatpak remote-add flathub ...` answers `Uzak flathub zaten var` (remote already exists), because `/etc/flatpak/remotes.d/flathub.flatpakrepo` configures it. The r13 failure (GPG engine) is gone.
- Install: NOT RUN correctly (16.6, FP row). The install and list commands were typed with the wrong letter (see 16.7).

### 16.2 Item 2: alp (commit b090ce1)

- The installed `/usr/lib/alp/alp.py` is the repo file (record `alp` 0.9-r13, REPLACE). `cmp` identical.
- `alp check` with the installed copy (`chroot r4-root /usr/bin/alp check`): rc 0, 512 packages.
- `alp search fastfetch` and `alp list` without `--index`: rc 0 in the chroot as root, with LANG=C and with LANG=tr_TR.utf8, and as uid 1001 (testuser).
- In the guest (B1, Konsole), `alp list` printed `'list' diye bir komut yok` (argparse invalid choice). The same command passes in the chroot. Cause not established: the on-screen token could not be read at this size, and a Turkish-Q dotless `ı` typed in place of `i` would produce this message. Open; see 16.7.

### 16.3 Item 3: curl (no commit; answer is a usage error, not a broken binary)

- `curl --version` in the guest and in the chroot: curl 8.21.0, libcurl with OpenSSL.
- The earlier "silent" runs used `curl -I ftp.gnu.org`. curl treats a host name that starts with `ftp.` as FTP by default. The verbose run (FP14, `curl -v -m 15 -o h3.txt ftp.gnu.org`) connected to ftp.gnu.org port 21 and printed an FTP directory listing (`wc -c h3.txt` = 1382). A HEAD request on FTP prints nothing, which is what the earlier runs showed.
- The network path works: `curl -sS -m 10 -I -o h1.txt 10.0.2.2` in B1 printed `curl: (7) Failed to connect to 10.0.2.2 port 80 ... Could not connect to server` (the gateway has no web server, which is the expected error).
- Correct form for the checks: `curl -I http://ftp.gnu.org/` or `https://`. Not run to completion in r14 (the flatpak run took the network time; see 16.6).

### 16.4 Item 4: fusermount3 setuid (commit b090ce1)

- BLFS stable page `https://www.linuxfromscratch.org/blfs/view/stable/postlfs/fuse.html` (Fuse 3.17.4, fetched and quoted): the install command is `chmod u+s /usr/bin/fusermount3 &&`; the short description calls it "a suid root program to mount and unmount Fuse filesystems".
- Record: `fuse3-3.18.2-leftover` 3.18.2-r13, 16 files, fusermount3 mode 4755 (manifest mode 2541 = 0o4755). The package key of the r7 record was kept.
- The record tool masked modes with `& 0o777` and dropped setuid; `scripts/rebuild/r8/stage-record-r8.py` now keeps `0o7777`.
- Verified: r4-root and the r14 installed disk (read-only): `4755`. ISO squashfs: `-rwsr-xr-x`.

### 16.5 Items 5 and 6 (commits b090ce1, be6a7fe, fd54b85)

- Item 5, keyboard: the installer already writes `/etc/X11/xorg.conf.d/00-keyboard.conf` (XkbLayout tr) and `/etc/vconsole.conf` (KEYMAP trq) on the installed disk. What was missing is KDE's own default: record `alpbahos-keyboard` 0.9-r13 adds `/etc/xdg/kxkbrc` (LayoutList=tr, Use=true). Result in B1 r14: the Plasma session types with the Turkish-Q keys (`-` and `/` typed correctly). **Still open:** `localectl status` shows `VC Keymap: trq` and `X11 Layout: (unset)` even with 00-keyboard.conf present (the cause is not analysed). Design note for Q/F detection added to `docs/verification/user-feedback-keyboard-2026-11-09.md` (design only, not built).
- Item 6, SDDM logo: record `sddm-alpbahos-r13` 0.9-r13 patches Main.qml so the logo Image opacity no longer follows `uiVisible`. **FAIL on screen:** the logo is not visible on the login frame (B1 r14 greeter at 95 s) nor on the disk-boot frame (REC1b at about 110 s). The patch is on the disk (`grep -c "opacity: 1"` = 1); the reason the logo does not render is not found.

### 16.6 Matrix on sha `ae1ef2d8...` (ISO r14)

Accelerator KVM with `-cpu qemu64` unless marked. Evidence under `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r14/`.

| Row | Accel | Result | Evidence |
|---|---|---|---|
| L1 live UEFI, desktop at 130 s, 3 runs | KVM | **PASS 3/3** (taskbar, Install icon, Welcome Center window) | `L1-1/shot-130.png`, `L1-2/`, `L1-3/` |
| I1 Calamares BIOS MSDOS, erase vda, tr, Turkish-Q, testuser | KVM | **PASS** (completion page "Her şey tamam", AlpbahOS 0.9 Beta) | `I1/i-09-done.png`; `images/inst-bios-msdos-r14.raw` |
| I1a disk checks (read-only) | none | **PASS**: fstab root UUID e383eacb... = blkid; no live account; testuser; hostname alpbahos-test; VERSION 0.9 Beta; grub.cfg; MBR GRUB; fusermount3 4755; kxkbrc LayoutList=tr; xkb tr; SDDM patch present | this section |
| I2 Calamares UEFI GPT, same user | KVM | **PASS** (install completed; unmount logged). The final screen is not captured (the screen had idle-locked) | `I2/serial.log`; `images/inst-uefi-gpt-r14.raw` |
| I2a disk checks (read-only) | none | **PASS**: fstab root 84f8616b... and /boot/efi B5BA-4BFE = blkid; no live; testuser; VERSION; grub.cfg; fusermount3 4755; kxkbrc; ESP EFI/alpbahOS/grubx64.efi and EFI/boot/bootx64.efi | this section |
| B1 installed BIOS, virtio, login, desktop, fastfetch | KVM | **PASS** login, desktop, fastfetch (logo, "AlpbahOS 0.9 Beta", readable colours); **FAIL** `alp list` in the guest (16.2); **curl** shows the connection error to 10.0.2.2 (network OK); `localectl` X11 unset (16.5); SDDM greeter shows layout `us` | `B1/b1-desktop.png`, `b1-fastfetch.png`, `b1-alp-list.png`, `b1-greeter.png`, `b1-localectl.png`, `b1-curl.png` |
| U1 installed UEFI, virtio, hostnamectl | KVM | **PASS** hostnamectl (AlpbahOS 0.9 Beta, kvm, edk2). `systemctl --failed` **NOT RUN** (the double hyphen did not type; r13 U1 showed 0 loaded units) | `U1/u1-hostnamectl.png` |
| FP Flatpak remote, install one app | KVM | **remote PASS** (`flathub system`, 16.1). **Install NOT RUN**: `flatpak install` and `flatpak list` were typed with `ı` for `i`, so flatpak answered "'install' komutu değil" (not a command). Application install and run are open | `FP14/fp-remotes.png`, `FP14/fp-install.png`, `FP14/fp-list.png` |
| REC1 BIOS recovery, broken copy as /dev/vda, live ISO (CD first) | KVM | **PASS** (REC1b): `pkexec /usr/local/s*/alpbahos-recover` lists vda1; recovery runs to "recovery done; unmounting; reboot the installed disk"; the repaired disk reaches the display-manager frame. An earlier REC1 attempt typed `sb7n` for `sbin` and was rerun | `REC1b/rec1b-step0.png`, `rec1b-step1.png`, `REC1b-boot/rec1b-disk-greeter.png` |
| curl (file-based) | KVM | **answered** (16.3): FTP default for ftp. hosts; the `http://` form is the check to use | `FP14/fp-curl-v.png`, `fp-curl-wc.png` |

Notes: the first lane run for I1 and I2 clicked Install at y=666 (the BIOS summary button is at about y=652); I1 was confirmed by hand. The orphans described in 16.7 are two live VMs whose run directories were removed during cleanup.

### 16.7 Failures, open items, not run

- Flatpak install: see the FP line (16.6).
- alp `list` in the guest: not explained (16.2).
- Double hyphen `--` did not type correctly in the Turkish-Q session (`systemctl --failed` and `pkexec flatpak remote-add --if-not-exists` gave `unrecognized option` / `Bilinmeyen seçenek`). Single-hyphen commands type correctly. Relevant to the keyboard feedback; not analysed.
- Letter `i`: the harness sends the `i` key (qcode i). In the Turkish-Q session that key gives dotless `ı`, which explains the failing words: `alp list` (B1), `flatpak install` and `flatpak list` (FP14), and the `sbin` typed as `sb7n` in the first REC1 attempt (the glyph looked like `7` at this size). Turkish-Q puts dotted `i` on the apostrophe key, so the harness must send apostrophe for `i`. Most likely cause; not verified by a direct test. The system behaves as Turkish-Q does; this is a harness mapping fault, not a product fault, unless a real user reports the same.
- SDDM logo not visible on the login or boot frame (16.5).
- localectl X11 layout unset (16.5).
- Idle lock: the Plasma screen locks and blanks after about 10 minutes idle, which hides the installer and flatpak screens.
- Orphan QEMU processes: two live VMs from the round 14 lanes (the L1 live runs) survive because their run directories were removed during a cleanup mistake, so QMP quit cannot reach them. Their processes are not killed here (rule: end VMs with QMP quit only). They need to be closed by the user or the coordinator.
- Not run: S1 shutdown and R1 reboot on sha r14 (the round 13 results stand for r13); sound on the r14 rows except B1; the full 90 s session; the Plasma menu (Kapat) on r14.
- ESP check: done for the I2 disk (16.6).
- Commits in this round (local, not pushed): 1fadc0f (GnuPG), b090ce1 (alp, fuse3 setuid, keyboard record, stage-record mode fix), be6a7fe (SDDM logo), fd54b85 (keyboard design note).

## 17. Round 15 (2026-11-10): SDDM greeter, keyboard file, harness typing, matrix on ISO r15

ISO: `scratch-lfs-bench/images/alpbahos-beta-0.9-2026-11-09-r15.iso`, sha256 **`e2077dcfcd384963fbc1dce981deb663bfbe8c079094121e345a8e6463d1d5ae`**, 4742668288 bytes, `TAG=r15`. Checked read-only in the squashfs: `etc/sddm.conf` (Current=alpbahos, GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml), `usr/lib/alpbahos/target-cleanup.sh` (XkbVariant removal), `Main.qml` (logo layout), `usr/lib/alp/alp.py` equal to the repo file. The first r15 build (sha c0330db1) was discarded before any run because the logo record was missing from r4-root.

### 17.1 Item 1: SDDM logo (commits 0b4a42c)

- Cause, found with the greeter's own test window and the journal: the greeter could not import `org.kde.breeze.components` (its QML import path had no `/usr/lib/qml`), so the theme errored and SDDM showed its fallback layout (top bar `Oturum / Klavye Düzeni`). The main `/etc/sddm.conf` also had an empty `[Theme] Current=`, which wins over the drop-in `/etc/sddm.conf.d/alpbahos-theme.conf`. The logo was never drawn because the theme never loaded.
- Fix: record `sddm-config-r15` 0.9-r15 (`/etc/sddm.conf`: `Current=alpbahos`, `GreeterEnvironment=QML2_IMPORT_PATH=/usr/lib/qml`); record `sddm-alpbahos-r13` 0.9-r15 (logo at the top centre, 120 px, below the status bar).
- Evidence: test copy (greeter test before the ISO), `SDT5/g5-greeter.png` (alpbahos logo at the top and centre); ISO r15 disk boot after recovery, `REC1-boot/rec-disk-greeter.png` (logo at the top and centre); B1 greeter `B1/b1-greeter.png`.
- Result: **PASS** (visible on the greeter frames).

### 17.2 Item 2: keyboard, localectl (commit 5c19748)

- `localectl status` showed `X11 Layout: (unset)` with `00-keyboard.conf` containing `XkbLayout "tr"`. Cause: the empty `Option "XkbVariant" ""` line that Calamares writes; systemd-localed does not parse the file with it. Test: removing that line made `localectl status` show `tr` (`PRB3`, probe frame).
- Fix: `target-cleanup.sh` (runs in the installed system after the keyboard step) removes that line.
- Evidence: I1 r15 disk check `XkbVariant lines: 0`; `B1/b1-localectl.png` (`VC Keymap: trq`, `X11 Layout: tr`).
- Result: **PASS**.

### 17.3 Item 3: harness typing (Turkish-Q)

- In the Turkish-Q session the harness key `i` (qcode i) gives dotless `ı`; dotted `i` is the apostrophe key. Confirmed by `echo ii` (apostrophe) printing `ii`. Earlier failures (`alp list`, `flatpak install`, `sbin`) were this.
- `:` is shift + the dot key (`combo shift slash`); the first curl run typed `$` for `:`.
- The double hyphen works with two `equal` keys (`echo a--b` printed `a--b`). The earlier `--` failures came from the mixed round 13/14 typing.
- Concurrent probe runs typed into one VM and garbled the commands; each run is now started once.

### 17.4 Matrix on sha `e2077dcf...`

KVM with `-cpu qemu64` for every row (no TCG row was in this round). Evidence under `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r15/`.

| Row | Accel | Result | Evidence |
|---|---|---|---|
| L1 live UEFI, desktop at 130 s (1 run) | KVM | **PASS** (desktop, taskbar, Install icon) | `L1-1/shot-130.png` |
| I1 Calamares BIOS MSDOS, erase vda, tr, Turkish-Q, testuser | KVM | **PASS** ("Her şey tamam"); disk check PASS (fstab UUID = blkid 7f1645da..., no live account, testuser, VERSION 0.9 Beta, fusermount3 4755, kxkbrc tr, no XkbVariant, SDDM Current=alpbahos, import path, logo layout) | `I1/i-09-done.png`; `images/inst-bios-msdos-r15.raw` |
| I2 Calamares UEFI GPT | KVM | **PASS** ("Her şey tamam"); disk check not repeated this round (r14 check PASS) | `I2/i-09-done.png`; `images/inst-uefi-gpt-r15.raw` |
| B1 installed BIOS, virtio: login, greeter, desktop, localectl, fastfetch, alp list, systemctl --failed | KVM | **PASS** for greeter with logo, desktop, `localectl` (`X11 Layout: tr`), fastfetch, `alp list` (lists the packages, no `--index`), `systemctl --failed` (0 loaded units). **curl**: the first run typed `:` as `$`, so the URL was wrong (fixed in 17.3) | `B1/b1-greeter.png`, `b1-localectl.png`, `b1-fastfetch.png`, `b1-alp-list.png`, `b1-failed.png` |
| B1 curl (rerun CURL15, `curl -sS -m 15 -I -o h2.txt http://ftp.gnu.org/`) | KVM | **PASS**: the response headers of ftp.gnu.org are in the file (Content-Security-Policy, X-Frame-Options, Content-Type text/html). The status line is above the captured area | `CURL15/c-result.png`, `c-wc.png` |
| U1 installed UEFI, virtio: login, hostnamectl, failed units, flatpak | KVM | **PASS**: hostnamectl (AlpbahOS 0.9 Beta, kvm, edk2), `systemctl --failed` (0 loaded units), `flatpak remotes` (`flathub system`) | `U1/u1-hostnamectl.png`, `u1-failed.png`, `u1-fp-remotes.png` |
| FP flatpak install org.gnome.Calculator (in U1) | KVM | **PASS**: `flatpak install -y flathub org.gnome.Calculator` ends with "Kurulum tamamlandı" (org.gnome.Platform 51 and the app, 2.0 GB); `flatpak list` shows org.gnome.Calculator (system); the app window opens. The terminal shows GPU and dbus warnings from the app, not from flatpak | `U1/u1-fp-install.png`, `u1-fp-list.png`, `u1-calc.png` |
| REC1 BIOS recovery, broken copy (initramfs removed, grub.cfg truncated), live ISO CD first | KVM | **PASS**: `pkexec /usr/local/s*/alpbahos-recover` lists vda1; the six steps end with "recovery done; unmounting; reboot the installed disk"; the repaired disk boots to the alpbahos greeter with the logo | `REC1/rec-step0.png`, `rec-step1.png`, `REC1-boot/rec-disk-greeter.png` |

Not run on sha `e2077dcf`: L2, L3, L4 (TCG and BIOS live), I2 disk check, B2 (AHCI), B3 (NVMe 2G), U2 (NVMe + sound), S1 (shutdown cycles), R1 (reboot through the greeter). The round 14 and round 13 results for these rows do not carry over to this sha.

### 17.5 Open items

- Gate: **not met.** The rows above pass; the rows listed as not run have no evidence on this sha.
- Real-PC test and the publication decision: the user's.
- Coredump crash: not reproduced in this round (S1 was not run on r15); still not proven fixed.
- Keyboard feedback from the real PC (`docs/verification/user-feedback-keyboard-2026-11-09.md`): still open; this round changes only the installed system's X11 keyboard file and the KDE default.
- Space: the r13 installs (`inst-*-0.9b.raw`), the r14 installs (`inst-*-r14.raw`) and the broken-copy work files were removed to make room; the r13 and r14 evidence logs stay.
- Commits this round (local): 0b4a42c (SDDM), 5c19748 (keyboard file), the section and status commit below.
