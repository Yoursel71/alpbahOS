# Shortcut conflict list — UI-02 / M08

Status (updated 2026-11-06):

- **Action IDs and upstream defaults** were checked against the KDE Plasma 6.4.4 source code (26 Sep 2026). No shortcut was tested in a real Plasma session at that time.
- **Live check in the QEMU LFS test image (5 Nov 2026):** `verify_shortcuts_live.py` returned **19 pass, 1 out of scope, RC=0**. The out-of-scope row is `clipboard-ops` (application layer). Evidence: [vm-session-2-2026-11-05.md](../../docs/verification/vm-session-2-2026-11-05.md). An earlier run on the same day, before the profile was installed correctly, gave 7 pass, 11 not active, 1 out of scope and 1 unrecorded (see [m07-m08-qemu-evidence-2026-11-05.md](../../docs/verification/m07-m08-qemu-evidence-2026-11-05.md)). That run is kept as history.
- **Single source:** [`shortcuts.json`](shortcuts.json). The system file [`generated/kglobalshortcutsrc`](generated/kglobalshortcutsrc) is generated from it by [`generate_kglobalshortcutsrc.py`](generate_kglobalshortcutsrc.py).
- **Decision:** D118 (Windows-familiar profile, generated from one source). Plan: [docs/MASTER_PLAN.md](../../docs/MASTER_PLAN.md) §6. The earlier Windows-host test plan is archived at [docs/archive/HYPERV_PLAN.md](../../docs/archive/HYPERV_PLAN.md).

## 1. Consistency within the profile (automatic)

The generator checks the profile on every run and writes no file if there is an error. Errors are: an unknown key name; the same action defined twice; the same key bound to two actions; a row whose promised key is not bound; and an upstream key removed without a reason. [`tests/test_m08_desktop_profile.py`](../../tests/test_m08_desktop_profile.py) checks these rules and that every row of the MASTER_PLAN §6 table is in the profile. The test count was 19/19 on 26 Sep 2026 (Windows, historical). This does not replace a real `kglobalaccel` registration, which is checked by the live script.

## 2. Conflicts with Plasma 6.4.4 upstream defaults (from source code)

Sources are the files at tag `v6.4.4` (GitHub KDE mirror). Dolphin is a KDE Gear component, not part of Plasma; `v25.08.1` was used as the reference, and it was not yet built in the target image at that time.

| Shortcut | Upstream 6.4.4 status | alpbahOS decision | Source |
|---|---|---|---|
| Alt+Tab / Alt+Shift+Tab | `Walk Through Windows` = **Meta+Tab, Alt+Tab**; reverse direction Meta+Shift+Tab, Alt+Shift+Tab | Alt+Tab is kept; Meta+Tab and Meta+Shift+Tab are **removed** from window switching | kwin `src/tabbox/tabbox.cpp` |
| Win+D | `Show Desktop` = Meta+D (toggle) | Unchanged | kwin `src/useractions.cpp` |
| Win+E | Dolphin `_launch` = Meta+E | Unchanged. Confirmed working in QEMU on 5 Nov 2026 | dolphin `src/org.kde.dolphin.desktop` |
| Win+L | `ksmserver/Lock Session` = Meta+L, Screensaver; old Ctrl+Alt+L is not in 6.4.4 | Unchanged. KScreenLocker is not built yet, so this does not work yet (D133 brings it back; SCREENLOCK-01) | kscreenlocker `ksldapp.cpp`, `settings/kscreensaversettings.cpp` |
| Win+R | KRunner = Alt+Space, Alt+F2, Search; **Spectacle `RecordRegion` = Meta+Shift+R, Meta+R** | Meta+R is added to KRunner; removed from Spectacle (Meta+Shift+R stays) | plasma-workspace `krunner/org.kde.krunner.desktop.cmake`; spectacle `desktop/org.kde.spectacle.desktop.cmake` |
| Win (alone) | plasmashell `activate application launcher` = Meta, Alt+F1 | Unchanged. In Plasma 6 a lone Meta is a normal global shortcut | plasma-workspace `shell/shellcorona.cpp` |
| Win+I | System Settings = Tools | Meta+I is added; upstream has no other Meta+I (KWin only has Meta+Ctrl+I for invert) | systemsettings `app/systemsettings.desktop`; kwin `src/plugins/invert/invert.cpp` |
| Win+Left / Right | `Window Quick Tile Left/Right` = Meta+Left/Right | Unchanged | kwin `src/useractions.cpp` |
| Win+Up | `Window Maximize` = Meta+PgUp; **Meta+Up = `Window Quick Tile Top`** | Meta+Up goes to maximise; quick tile to top has no shortcut. Maximise toggles (restores if already maximised) | kwin `src/useractions.cpp` (`MaximizeOp`) |
| Win+Down | `Window Minimize` = Meta+PgDown; **Meta+Down = `Window Quick Tile Bottom`** | Meta+Down goes to minimise; quick tile to bottom has no shortcut | kwin `src/useractions.cpp` |
| Win+Tab | `Overview` = Meta+W; **Meta+Tab is window switching** | Meta+Tab goes to Overview; Meta+W stays | kwin `src/plugins/overview/overvieweffect.cpp` |
| Alt+F4 | `Window Close` = Alt+F4 | Unchanged | kwin `src/useractions.cpp` |
| Ctrl+Shift+Esc | System Monitor = Meta+Esc; KWin `Kill Window` = Meta+Ctrl+Esc (different key) | Ctrl+Shift+Esc is added | plasma-systemmonitor `org.kde.plasma-systemmonitor.desktop` |
| Win+Shift+S | Spectacle `_launch` = **Print, Meta+Shift+S** (opens the app in default mode); region capture = Meta+Shift+Print | Meta+Shift+S goes directly to `RectangularRegionScreenShot`; Print still opens the app | spectacle `desktop/org.kde.spectacle.desktop.cmake` |
| Ctrl+C/V/X/Z | Not system shortcuts | Application layer; terminal exception in `profiles/shell/README.md` | — |

All KWin plugins (`src/plugins/*.cpp`, 161 files) were scanned for default bindings that include Meta. No other conflict with the profile keys was found. Only the relevant files of the Plasma components were read, not all of them. The real state on an installed system is measured by `verify_shortcuts_live.py`.

### 2.1 Accepted differences from upstream (deliberate)

- On Windows, Win+Down first restores a maximised window and a second press minimises it. KWin has no built-in sequence like this. In this profile Win+Down minimises directly; restoring uses Win+Up (toggle).
- Quick tile to top and bottom (Meta+Up/Down) has no shortcut. System Settings can assign one.
- Win+Shift+Tab is not bound to any action (Windows has no equivalent either).

## 3. Capture risk at the VM and host level

The project is developed on Fedora with test VMs under QEMU/KVM (D106).

- **Host capture is not verified.** When a key combination is sent to a QEMU window, the host desktop may handle it instead of the VM (Meta+L, Meta+D and Meta+Tab are the likely cases). This has not been tested on this host.
- **Registration check:** `verify_shortcuts_live.py` reads the registration over D-Bus (read-only). It does not depend on how keys reach the VM, so it can be run over SSH.
- **Trigger check:** whether pressing a key actually runs the action can be tested with a monitor-sent key (the QEMU monitor `sendkey` was used for Meta+E on 5 Nov 2026), and by hand. Real hardware testing is needed before release (D106: USB test on a real PC; BETA-01).
- Results are recorded at both levels separately (MASTER_PLAN §6).

## 4. Open decisions

1. Win+Down: is the Windows "restore first, then minimise" sequence needed? If yes, a small KWin script is needed. That is not a ready-made component, and it needs a separate approval.
2. The "Defaults" button in Settings returns to the upstream KDE default, not to the alpbahOS profile. The default is declared by the application that registers the action. For now, going back to the alpbahOS profile means deleting the related entry in the user's `~/.config/kglobalshortcutsrc`. Whether a user-facing "restore alpbahOS shortcuts" action is needed is open (MASTER_PLAN §6: "can be edited and return to the default").
3. Win+L depends on the decision to build KScreenLocker again (D133; SCREENLOCK-01).

## Next step

- Run the live check on an installed system with the profile in place, not only in the QEMU test image. The 5 Nov 2026 pass (19/20) is on the test image, which had the profile installed by hand (see [022-t2-kisayol-2026-11-05.md](../../docs/handoffs/ai/022-t2-kisayol-2026-11-05.md)).
- Test each key by hand in the VM and record the result.
- Repeat on a real PC before release (D106).
