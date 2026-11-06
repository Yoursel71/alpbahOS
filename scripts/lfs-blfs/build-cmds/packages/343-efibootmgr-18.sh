# efibootmgr 18 build commands (added 2026-11-06 as order row 343; BLFS 12.4-systemd book page postlfs/efibootmgr.html).
# source: https://github.com/rhboot/efibootmgr/archive/18/efibootmgr-18.tar.gz
# verification: book MD5 e170147da25e1d5f72721ffc46fe4e06 (book-verified, matches the downloaded file 2026-11-06); sha256 442867d12f8525034a404fc8af3036dba8e1fc970998af2486c3b940dfad0874 (computed, not in book).
# Requires efivar-39 (row 342) and popt-1.19 (row 341); both are found through pkg-config.
# Book flags: EFIDIR=LFS (the distro subdirectory under /boot/efi/EFI) and EFI_LOADER=grubx64.efi (the default loader name that GRUB installs).
# Installed: /usr/sbin/efibootmgr and /usr/sbin/efibootdump. The package has no test suite.

# --- [BUILD] ---
make EFIDIR=LFS EFI_LOADER=grubx64.efi

# --- [INSTALL,ROOT] ---
make install EFIDIR=LFS

# --- [CONFIG] ---
# smoke test: efibootmgr prints its version (it runs without an EFI firmware)
out=$(efibootmgr --version 2>&1 || true); printf '%s\n' "$out" | grep -q 'version 18'
