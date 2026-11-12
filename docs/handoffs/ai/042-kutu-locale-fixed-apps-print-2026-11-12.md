# 042: KUTU-LOCALE-01 is already fixed in r4-root; APPS-02, PRINT-01, FONTS-01, SHELL-R4-01, DRIVERS-01 added (2026-11-12)

For: the other session (rc02, beta-rc02-2026-11-12.md section 4 "KUTU: where the fix belongs") and the next session.

Task / status: the rc02 KUTU finding (installed `LANG=tr_TR.utf8`, distrobox-init stops) was fixed in r4-root
before rc02 was recorded, and round 42 shows it fixed in QEMU. Since handoff 041, r4-root got more records.

Host, branch and commit: host `thewo`, `wt-t2-kisayol`, branch `claude/t2-kisayol-2026-11-05`, pushed to `yoursel`
main (this note's commit).

## KUTU-LOCALE-01 (no need to fix again)

- Installer: Calamares `locale.conf` `localeGenPath` -> `/usr/share/alpbahos/calamares/locale.gen` (the image's 13
  UTF-8 locales in the canonical spelling; `build-iso.sh` installs it), commit 067ee33. New installs write
  `LANG=tr_TR.UTF-8` (round 42 disk checks I1 and I2).
- alp: every distrobox/podman call of the Debian box runs with LANG/LANGUAGE/LC_* rewritten from `.utf8` to `.UTF-8`
  (`_kutu_env`), so installs made before the fix also work; record `alp-r42 0.9-trust1.7`.
- Round 42 KUTU row ([record](../../verification/round-42-2026-11-12.md)): testuser `alp install -y htop` and a real
  `sudo -n alp install -y cowsay` pass, htop runs in Konsole; NVIDIA recipe row passes with the real sandbox.
- The netavark records in r4-root are `netavark 1.17.2` / `aardvark-dns 1.17.1` (73d1a90); rc02's
  `netavark-rc02` records are in the rc02 root only.

## Added to r4-root since handoff 041 (all pushed)

| Item | Records / rows | Commit |
|---|---|---|
| SHELL-R4-01 (D119): Zsh default user shell | zsh-autosuggestions 0.7.1, zsh-syntax-highlighting 0.8.0, alpbahos-zsh-profile-r42c; Calamares userShell /bin/zsh | 274f9c9 |
| DRIVERS-01 (D166): installer page "Sürücüler" | packagechooser@drivers + contextualprocess@drivers-mark; alpbahos-drivers-r43 (first-boot service, notifier); sof-firmware 2026.09.2 | 8ab777a, 9934199 |
| APPS-02 (D127): the KDE apps | openjpeg, poppler (+data), exiv2, libkexiv2, kColorPicker, kImageAnnotator, 7zip, Okular, Gwenview, Ark, Kate (rows 437-448); mimeapps and hicolor cache | eda10b8 |
| PRINT-01 step 1, FONTS-01 | ghostscript, qpdf, pdfio, libexif, MuPDF, libcupsfilters, libppd, cups-filters (rows 449-456); DejaVu, Liberation; installer user in lpadmin | a479340 |
| alp | a user's `--dry-run` needs no lock (0af8f51); ldconfig/depmod triggers; `unpack: false`, kernel tokens; nvidia recipe in catalogue v4 | 0af8f51, a3b4588 |

Harness notes: `r20-lanes.sh` and `matrix-r21.sh kfgo` take `DRIVERS_PAGE=1` for ISOs with the new page (round 43+);
round 43 runs on such an ISO. Do not edit a matrix script while a row runs from it (bash reads scripts as it goes).

## Next single action

Round 43 results (APPS2, DRV, Zsh, driver page in the installs), then PRINT-01 step 2 (Avahi, CUPS with DNS-SD,
cups-browsed) and a round 44 ISO.
