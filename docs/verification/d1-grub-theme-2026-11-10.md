# D1 GRUB-THEME-01: branded GRUB menu (round 22), 2026-11-10

Review item D1 of the 2026-11-10 master task. Decisions D155 (wordmark) and D156 (GRUB theme). Host `thewo` (Fedora),
QEMU/KVM, `-cpu qemu64`. The look waits for the user's approval; nothing here is a claim about real hardware.

## What was built

| Part | Where | Notes |
|---|---|---|
| Theme generator | [branding/grub-theme/tools/build_grub_theme.py](../../branding/grub-theme/tools/build_grub_theme.py) | Host tool. Builds the .pf2 fonts with grub2-mkfont 2.12 (the target GRUB 2.14 has no FreeType and no grub-mkfont), the mark, the 9-slice selected row with the "Enter" hint baked into its right slices, the progress bar pixmaps and `theme.txt.in`. Label positions come from the device widths stored in the .pf2 files (GRUB does no kerning). |
| Theme files | [branding/grub-theme/alpbahos/](../../branding/grub-theme/alpbahos/) | Committed output; [MANIFEST.txt](../../branding/grub-theme/alpbahos/MANIFEST.txt) has the exact grub2-mkfont commands, the TTF and zip sha256 values and the sha256 of every file. |
| Packages in r4-root | `font-inter 4.1`, `font-jetbrains-mono 2.304`, `alpbahos-grub-theme 0.9-d1` | [scripts/rebuild/d1/product-d1.py](../../scripts/rebuild/d1/product-d1.py) checks the zip pins and stages; [product-d1.sh](../../scripts/rebuild/d1/product-d1.sh) records with `apply-r7.sh` + `stage-record-r8.py` (alp adopt-base). `theme.txt` gets "0.9 Beta · x86_64" from r4-root `/etc/os-release` `VERSION`. fontconfig lists "Inter Variable" and "JetBrains Mono" in the chroot. |
| Installer | [scripts/lfs-blfs/calamares/modules/grubcfg.conf](../../scripts/lfs-blfs/calamares/modules/grubcfg.conf) | `GRUB_TERMINAL_OUTPUT=gfxterm`, `GRUB_GFXMODE=auto`, `GRUB_FONT=/boot/grub/themes/alpbahos/jbm-16.pf2` (the base has no unicode.pf2), `GRUB_THEME=…/theme.txt`. |
| Name | [branding.desc](../../scripts/rebuild/iso/live/calamares/branding/branding.desc) | `bootloaderEntryName: alpbahOS` (was `AlpbahOS`); Calamares writes it to `GRUB_DISTRIBUTOR`. `efiBootloaderId` is set separately in bootloader.conf, so the EFI directory does not change. Other "AlpbahOS" spellings: NAME-CASE-01. |
| Preview | [scripts/rebuild/d1/grub-preview.sh](../../scripts/rebuild/d1/grub-preview.sh) | Small BIOS+UEFI ISO with the target's grub-mkimage 2.14 and modules and only a menu, for look checks without an install. |
| Test rows | [scripts/rebuild/d1/d1-grub-tests.sh](../../scripts/rebuild/d1/d1-grub-tests.sh) | `menu` (installed image unchanged, `-snapshot`, no key pressed) and `mode` (reflink copy with only `set gfxmode=auto` changed). `vm-start.sh` got an opt-in `VGA` display device (default unchanged). |

Font sources: Inter 4.1 (`Inter-4.1.zip`, sha256 `9883fdd4…b11e`) and JetBrains Mono 2.304 (`JetBrainsMono-2.304.zip`,
sha256 `6f6376c6…7bbf`), both SIL OFL 1.1, GitHub releases over HTTPS. Upstream publishes no checksum and the GitHub API
gave no asset digest, so these are first-download pins, not upstream-verified.

## Findings while building

- With `GRUB_TERMINAL_OUTPUT=console`, grub-mkconfig runs `export LANG=C`; that is why the old installed menu was
  English. With gfxterm the generated grub.cfg now has `set lang=tr_TR`, and GRUB's own texts are Turkish
  ("… açılıyor", command-line help). The entry titles stay English: GRUB 2.14's `tr.mo` has no translation for
  "%s, with Linux %s" or "UEFI Firmware Settings".
- GRUB gives every `progress_bar` at least 28 px of height (`progress_bar_get_minimal_size`), so the 4 px bar is a
  28 px component whose pixmaps keep the outer rows in the background colour.
- GRUB does not expand `*.pf2` without the regexp module; the preview loads each font by name (00_header does the same).
- Under QEMU the firmware gives GRUB no EDID mode: `gfxmode=auto` gives 640x480 on SeaBIOS (also 800x600 with
  `-device VGA,edid=on`) and 1280x800 on OVMF. The product keeps `auto` (the display's preferred mode on real
  hardware, 640x480 when none); 1280x720 and 1920x1080 were shown on copies with only the gfxmode line changed.
- The countdown is three labels ("Seçili sistem ", the number in #ffc45d, " saniye içinde başlatılacak"); the suffix
  position assumes a one-digit timeout (product: 5). With 10 or more seconds the number overlaps the suffix (seen in
  the preview with 30 s).
- The menu area has 3 rows (BIOS install: 1 entry; UEFI: 2); the countdown sits under the area, not under the last entry.

## Runs

ISO `alpbahos-beta-0.9-2026-11-09-r22.iso`, sha256 `04ceb551c3e5d50606959e9b8e41c48f0dc3d63a3082614c69892f5d8c167cd0`,
built with `sudo env TAG=r22 bash scripts/rebuild/iso/build-iso.sh` (log `scratch-lfs-bench/d1/build-r22.log`; all
gates passed). Installs with `ROUND=r22 bash scripts/rebuild/r20/r20-lanes.sh <iso> installs` (I1 BIOS MSDOS, L1 live
UEFI, I2 UEFI GPT). Evidence directory: `scratch-lfs-bench/lfs13-logs/iso-beta-0.9/r22/`.

| Row | Environment | Result | Evidence |
|---|---|---|---|
| I1 | BIOS MSDOS install from ISO r22 | PASS: install done; disk check: `GRUB_DISTRIBUTOR='alpbahOS'`, gfxterm, theme, font, `set lang=tr_TR`, 56 theme files in `/boot/grub/themes/alpbahos` | `r22/I1/`, `r22/disk-check-I1.txt` |
| I2 | UEFI GPT install from ISO r22 | PASS: install done, disk check written | `r22/I2/`, `r22/disk-check-I2.txt` |
| G1 | installed BIOS, image unchanged, `gfxmode=auto` | Boot PASS: themed menu at 640x480, countdown 5→1 with the bar, then the default entry boots (no key pressed); screen at 100 s is the greeter. Layout FAIL at 640x480: the mark (7 % + 220 px = 265 px) runs under the menu (starts at 39 % = 250 px), so the selected row has no left border, and the wordmark touches the countdown line. Open question to the user (smaller fixed sizes would shrink the design at every resolution; GRUB has no per-resolution layout). | [bios-auto-640x480-menu](d1-grub-theme-2026-11-10/bios-auto-640x480-menu.png), [bios-auto-booting](d1-grub-theme-2026-11-10/bios-auto-booting.png), [bios-after-countdown-100s](d1-grub-theme-2026-11-10/bios-after-countdown-100s.png) |
| G2 | installed BIOS, copy with `gfxmode=1280x720` / `1920x1080` | PASS: menu at both sizes; E opens the editor in the theme frame | [bios-1280x720-menu](d1-grub-theme-2026-11-10/bios-1280x720-menu.png), [bios-1920x1080-menu](d1-grub-theme-2026-11-10/bios-1920x1080-menu.png), [bios-1280x720-edit-e](d1-grub-theme-2026-11-10/bios-1280x720-edit-e.png) |
| G3 | installed UEFI, image unchanged, `gfxmode=auto` | PASS: menu at 1280x800 with "UEFI Firmware Settings" as the second row; countdown boots the default entry | [uefi-auto-1280x800-menu](d1-grub-theme-2026-11-10/uefi-auto-1280x800-menu.png), [uefi-after-countdown-100s](d1-grub-theme-2026-11-10/uefi-after-countdown-100s.png) |
| G4 | installed UEFI, copy with `gfxmode=1280x720` / `1920x1080` | PASS: menu at both sizes; C opens the command line (Turkish help text) | [uefi-1280x720-menu](d1-grub-theme-2026-11-10/uefi-1280x720-menu.png), [uefi-1920x1080-menu](d1-grub-theme-2026-11-10/uefi-1920x1080-menu.png), [uefi-1920x1080-cmdline-c](d1-grub-theme-2026-11-10/uefi-1920x1080-cmdline-c.png) |
| B1 | installed BIOS, `OUTD=… diag-r21.sh bios` (reflink copy) | PASS: session up, failed units 0, NetworkManager active, curl https 200, sudo right/wrong/no-wheel rc 0/1/1, firewall probe blocked then open as control, zram 2,9G; idle used 1130.8 MiB at 6 GiB (PERF-01 unchanged) | `r22/diag-B1D.txt`, `r22/probe-B1D.txt` |
| U1 | installed UEFI, `FLATPAK=1 OUTD=… diag-r21.sh uefi` (reflink copy) | PASS: session up, failed units 0, curl https 200, `flatpak install org.gnome.Calculator` rc 0 and listed, firewall and zram active | `r22/diag-U1D.txt` |

VM boots this round: 4 preview ISOs (7 boots), 2 installs + 1 live (lanes), 6 GRUB rows, 2 diagnostics.

## Not done / not shown

- The user's approval of the look (required before D2).
- Real hardware: not tested (EDID `auto` mode, real GOP modes, HiDPI panels).
- Windows alongside (3+ entries, scrolling menu): not tested.
- The live ISO's own GRUB menu is not themed (D1 covers the installed system).
- The 1280x720 and 1920x1080 rows used copies with one changed line, not the product `auto` path.
- The 640x480 layout overlap (G1) is not fixed. 640x480 is what GRUB uses whenever the display gives no EDID mode
  (every QEMU BIOS run; old monitors and KVM switches on real PCs).
- Beta matrix rows not run on r22: L2-L4, B2, B3, U2, REC1, S1, R1. REC1 matters here: `alpbahos-recover` runs
  grub-install and grub-mkconfig again, the only other path that rewrites the themed config.
