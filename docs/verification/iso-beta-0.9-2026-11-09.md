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
