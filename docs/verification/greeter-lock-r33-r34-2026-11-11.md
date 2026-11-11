# Greeter and lock screen (rounds 32 to 34), 2026-11-11

Started by the user's report "Giriş ekranında bir sıkıntı var, yazılar uymamış; görüyorsun da neden bir şey demiyorsun?"
The defect was visible in Claude's own screenshots since round 19 and was not reported; that is recorded as a lesson.
Host `thewo`, QEMU/KVM `-cpu qemu64`. Screenshots: [greeter-lock-r33-r34-2026-11-11/](greeter-lock-r33-r34-2026-11-11/).

## Findings and fixes

| ID | Finding (evidence) | Cause | Fix (record) |
|---|---|---|---|
| GREETER-01 | Black clock, date, user name and action labels on the dark blue background; the logo's navy "alpbah" unreadable; greyed Hibernate ([before](greeter-lock-r33-r34-2026-11-11/greeter-before-r31.png)) | the greeter loaded no Kirigami platform plugin ("Could not find any platform plugin" in the journal): GreeterEnvironment had neither `QT_QPA_PLATFORMTHEME=kde` nor the KDE plugin path (Qt under /opt/qt6); alpbah-dark had no Complementary colours | `sddm-alpbahos-r33`: GreeterEnvironment += `QT_QPA_PLATFORMTHEME=kde,QT_PLUGIN_PATH=/usr/lib/plugins:/opt/qt6/plugins`; Hibernate `visible: sddm.canHibernate` (zram only, D152); logo = mark + live wordmark (D155). `alpbahos-colors-r33`: [Colors:Complementary], [Colors:Header] |
| SCREENLOCK-01 | The lock screen said "Kilit açılamadı" before any input and never unlocked ([before](greeter-lock-r33-r34-2026-11-11/lock-screen-before-pam-fix.png)) | `/etc/pam.d/kde` missing: PAM fell back to "other" (deny). Probably also the real cause of LIVE-LOCK-01 (round 20) | `alpbahos-pam-kde-r33`: `/etc/pam.d/kde` and `kscreensaver` as BLFS 13.1 (kde/plasma-all.html). BLFS's `kde-np` (pam_permit) is not added: nothing here needs it and a missing service fails closed |
| THEME-01 | the theme choice did not reach the lock screen | — | `alpbahos-welcome-tool-r32`: kscreenlockerrc wallpaper = the chosen package |
| LAYOUT-01 | blank Firefox/LibreOffice launchers on the taskbar (apps not in the image yet) | pinned without checking | `alpbahos-layout-r34`: pin only when `applicationExists` |
| Test harness | after the KDE theme the greeter login at 766,489 no longer submitted; r32's unlock step pressed Enter on the idle lock screen | layout change; test sequence | login click 622,474 in all current scripts; Shift wakes the lock form before typing |

## Runs

| Round | ISO | Result |
|---|---|---|
| r32 | `…r32.iso` | lock screen shows the Atatürk wallpaper after the Welcome choice; unlock failed (PAM, see above) |
| test copy (r32 install) | — | with the two PAM files: lock, password, desktop ([after](greeter-lock-r33-r34-2026-11-11/lock-screen-pam-fixed-testcopy.png)); with the greeter environment: light text in Inter |
| r33 | sha256 not kept (removed after the round) | greeter PASS ([r33](greeter-lock-r33-r34-2026-11-11/greeter-r33.png)): light text, Inter, readable logo, no Hibernate. The automated login did not submit (harness click, fixed); manual login at 622,474 PASS, the Welcome app opened |
| r34 | `…r34.iso` | PASS: greeter ([r34](greeter-lock-r33-r34-2026-11-11/greeter-r34.png)); Welcome rows; Meta+L lock form over the Atatürk wallpaper ([lock](greeter-lock-r33-r34-2026-11-11/lock-form-ataturk-r34.png)), password unlocks ([desktop](greeter-lock-r33-r34-2026-11-11/unlocked-desktop-r34.png)); taskbar with installed apps only ([taskbar](greeter-lock-r33-r34-2026-11-11/taskbar-installed-apps-only-r34.png)); B1/U1 log in at the new position, 0 failed units, greeter 4.21 s / 4.30 s; KSplash 48 frames |

## Also found while reviewing screenshots (round 34)

- The installer's partition legend ("Bölümlenmemiş alan…", "EFI Sistem", "alpbahOS") was drawn in a fixed black on the
  dark installer: Calamares `PartitionLabelsView::drawLabel` uses `Qt::black`. Patched (palette WindowText) and rebuilt,
  record `calamares-r34`; shown in round 35.
- The brand wallpaper's centre logo had the same navy wordmark; regenerated with the live wordmark (record
  `alpbahos-wallpaper-r35`, also the greeter background); shown in round 35.
