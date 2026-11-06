# M08 live PackageKit authorization and transaction retest — 30 September 2026

## Policy change

Added `configs/polkit/10-alpbahos-live-packagekit.rules` and the guarded applicator `scripts/configure-live-packagekit-polkit.sh`. The rule grants only the active, local `alpbahos` session these PackageKit actions: catalog install, reinstall, downgrade, remove, and update. It excludes PackageKit's untrusted local-file action and full system upgrade. Alp catalog/package signature verification was not established by this test and remains part of the M10 security review. The rule is explicitly for the volatile live ISO overlay and must not be included in a persistent installation. The script refuses non-alpbahOS roots and verifies the expected UID-1000 live account.

The rule was applied to the disposable NVMe `rootfs-xattrs` candidate. `bash -n`, Node syntax parsing of the rule, and `git diff --check` passed. A new ISO was produced while preserving prior candidates:

- NVMe: `/home/yrslf/alpbahOS-nvme/m10-alpha-20260930T/alpbahOS-live-m10-pk-liveauth.iso`
- HDD: `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-liveauth-20260930/alpbahOS-live-m10-pk-liveauth.iso`

## Runtime result

The OVMF/KVM guest reached Plasma at 1920×1080. In its active `alpbahos` desktop session:

- `pkcon install htop` completed without an authentication prompt.
- `htop --version` printed `htop 3.3.0`, proving the executable launched.
- `pkcon remove htop` reached PackageKit's `Finished`/100% removal state; afterward `alp list` showed no installed packages and `command -v htop` found no executable.
- This was the pre-fix candidate; it printed `Fatal error: alp: hata: Kurulu değil: htop` because PackageKit simulation mutated state.

## Remove-error diagnosis and candidate fix

Repeated the transaction with an `alp list` capture before and after install: before install the database was empty; after `pkcon install htop`, it listed `htop 3.3.0 recipe`. PackageKit reports separate “Testing changes” and commit stages. The installed backend ignored PackageKit's `simulate` transaction flag and invoked the real Alp operation during the test stage, then invoked removal again at commit; this accounts for the second call reporting “not installed.”

The Alp helper source now maps `simulate` to Alp `--json … --dry-run` for install/remove/update and leaves the real mutation to commit. Six helper regression tests pass, and direct `alp --json install --dry-run htop` produced a valid plan without adding htop to the candidate rootfs. However, the first `pk-sim-safe` ISO still exhibited the failure. Inspection showed that candidate had the edited helper in `/usr/lib/packagekit-backend/`, while PackageKit actually loads `/usr/share/PackageKit/helpers/alp/alpBackend.py`. A guarded deploy script now targets the real helper path; the corrected rootfs is being repacked as `pk-sim-helper`. The corrected `pk-sim-helper` ISO was booted under OVMF/KVM at 1920×1080. `pkcon install htop` completed, `htop --version` printed `htop 3.3.0`, and interactive `pkcon remove htop` completed its test and removal stages without the duplicate/not-installed fatal error. The final shell prompt returned cleanly. The PackageKit CLI install/remove gate is **PASS** on this candidate; Discover GUI removal remains open as recorded below. The ISO is preserved on the HDD at `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simfix-20260930/alpbahOS-live-m10-pk-simfix.iso`; runtime screenshots are in its `evidence/` directory. The VM had no virtual disks and was shut down after capture.

The first retest VM had no virtual disks; the corrected-ISO retest was also disksless and shut down after capture. The test affected only the disposable live overlay.


## Discover GUI transaction retest — 30 September 2026

The corrected `pk-sim-helper` ISO was booted in a fresh, disksless OVMF/KVM guest. Plasma reached 1920×1080 with the Atatürk wallpaper and a visible pointer. Discover opened, populated its home page, and returned one Htop 3.3.0 catalog result for `htop`. The details page showed the known `16.0 EiB` size and unknown license metadata.

Clicking **Install from alpbahOS** completed the mutation: a subsequent `alp list` showed `htop 3.3.0 recipe`. Discover's Installed-page search then showed Htop and a Remove action. Clicking Remove displayed an **Update Issue** toast (“There was an issue during the update or installation process. Please try again later.”), but a subsequent `alp list` reported `Kurulu paket yok.` The package was therefore removed despite Discover presenting the transaction as failed. The generic error needs its technical details/root cause before the Discover removal gate can pass. PackageKit CLI remove remains clean on this same corrected ISO.

Screenshots and post-removal state are preserved under `/mnt/alpbahOS-data/alpbahOS-build/artifacts/m10-packagekit-simfix-20260930/evidence/discover-ui/`. The guest had no virtual disk and was shut down; all package changes were confined to its disposable live overlay.
