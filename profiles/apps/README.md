# Default application profile (APPS-01, D127)

Status (updated 2026-11-06):

- **Built and tested in the QEMU LFS test image (5 Nov 2026):** Dolphin, Okular, KWrite, Gwenview, Ark (T6 payload, KDE Gear 25.08.3). Evidence: [vm-session-3-t6-2026-11-05.md](../../docs/verification/vm-session-3-t6-2026-11-05.md) and [vm-session-2-2026-11-05.md](../../docs/verification/vm-session-2-2026-11-05.md).
- **Planned, not built yet:** LibreOffice (Writer, Calc, Impress), VLC, Firefox (default browser). Their entries are written from upstream desktop files and are **not tested on alpbahOS**.
- **Not preinstalled:** KDE Edu (D127).

## Preinstalled applications (D127)

| Need | Application | Status |
|---|---|---|
| Files | Dolphin | Built; launched with Meta+E in QEMU (5 Nov 2026) |
| Terminal | Konsole + Zsh (D119) | Built in chroot |
| Settings | System Settings | Plasma component |
| Text | KWrite (Kate in the same tarball) | Built; MIME default `text/plain` checked in QEMU |
| PDF | Okular | Built; MIME default `application/pdf` checked in QEMU |
| Images | Gwenview | Built (T6); MIME not checked |
| Archives | Ark | Built (T6); MIME not checked |
| Screenshot | Spectacle | Plasma component |
| Calculator | KCalc | KDE Gear |
| System and disk | Plasma System Monitor, Filelight | Plasma component / KDE Gear |
| Browser | Firefox (default) | Planned, not built |
| Office | LibreOffice Writer, Calc, Impress | Planned, not built (D131: LibreOffice is the only office suite) |
| Media | VLC | Planned, not built |

## Files

- Single source: [`apps.json`](apps.json). It maps need → application → desktop file → default MIME types → verification code.
- Generator: [`generate_mimeapps.py`](generate_mimeapps.py) → [`generated/mimeapps.list`](generated/mimeapps.list). Install target: `/etc/xdg/mimeapps.list` (installed by `profiles/desktop/install-desktop-profile.sh`). A user's own choice in `~/.config/mimeapps.list` always takes precedence.
- Launchers that use `preferred://browser` and `preferred://filemanager` resolve through the `x-scheme-handler/https` and `inode/directory` associations in this file.
- Do not edit `generated/mimeapps.list` by hand. Run the generator:
  - `python3 -B profiles/apps/generate_mimeapps.py` writes the file.
  - `python3 -B profiles/apps/generate_mimeapps.py --check` exits 1 if the file is out of date.

## Verification levels

| Code | Meaning | Applications |
|---|---|---|
| `upstream` | MIME type is listed in the upstream desktop file | Dolphin, KWrite, Okular (PDF), VLC, Konsole/Spectacle/KCalc/System Monitor (no MIME) |
| `derleme_zamani` (build-time) | Upstream list is generated at build time; check the installed file | Gwenview (Qt image plugins), Ark (archive plugins) |
| `blfs_adi` (BLFS name) | Desktop file name is produced in the BLFS install step | Firefox, LibreOffice Writer/Calc/Impress (LibreOffice MIME lists checked against upstream `libreoffice-25-8`) |

Detail: Okular declares PDF in `okularApplication_pdf.desktop` (poppler generator), not in `org.kde.okular.desktop`. The default is written accordingly.

## Deliberately excluded

- **Wine (.exe association):** D130. Wine is provided through Bottles (Flatpak). No `.exe` association is written until Bottles is tested (COMPAT-01).
- **Steam:** D129. Native through multilib (D111). It has no MIME association, so it has no mimeapps entry.
- **Store:** the `alp` graphical store (D124, PKG-02) is not built.
- **Chrome:** not the default. It is a separate, verified install option (MASTER_PLAN §11).

## Verification record

Done on 5 Nov 2026 in the QEMU LFS test image (`disk-blfs3.img`), in the `alpbah` Plasma session:

| Check | Result | Evidence |
|---|---|---|
| `gio mime application/pdf` → Okular | passed | vm-session-3 |
| `gio mime text/plain` → KWrite | passed | vm-session-3 |
| `gio mime inode/directory` → Dolphin | passed | vm-session-3 |
| `okular test.pdf` opens under Wayland | passed | vm-session-3 |
| `kwrite test.txt` opens under Wayland | passed | vm-session-3 |
| `gio open` default launch (Okular) | partial: no `WAYLAND_DISPLAY` in the DBus activation environment | vm-session-3 |
| `xdg-mime` / `xdg-open` | not run (`xdg-utils` not in the image) | vm-session-3 |
| Gwenview and Ark MIME check | not run | vm-session-3 |

Still to do:

1. Fix the `gio open` activation environment (`WAYLAND_DISPLAY` for DBus-activated apps), or add `xdg-utils` and test `xdg-open`.
2. Check Gwenview and Ark MIME defaults.
3. Run LibreOffice, VLC and Firefox checks once they are built. Use the MASTER_PLAN §11 acceptance scenarios per application, recorded as pass/fail.
4. Check the `kabul` (acceptance) column for each application on a real target before any release claim.
