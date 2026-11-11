# 036 — ALP-TRUST-01 merge branch: what it brings and how to switch it on, 2026-11-11

For the session that builds the ISOs. Written by a sub-agent that worked in its own worktree; it did not touch the
main worktree, r4-root, ISOs, r3x folders or VMs.

Task / status: branch `claude/integ-alp-trust-2026-11-11` (worktree `/home/yrslf/alpbahOS/wt-integ`) is
`yoursel/main` (`e8222c6`) plus ALP-TRUST-01 (signed alp catalog, sandboxed recipe builds, D170-D174) and the
round 21 matrix record. Not pushed. Ready to merge; **merging changes nothing for the next ISO build** (below).

Host, branch and commit: host `thewo`; see `git log yoursel/main..claude/integ-alp-trust-2026-11-11`.

What the branch brings:

- `docs/handoffs/claude/alp-prototype/alp.py`: catalog must be signed (`index.json.sig`, gpgv, keyring and
  `allowed.txt` under `/usr/share/alp/keys/`); recipe hashes; recipe steps as user `alpbuild` in bubblewrap; stage
  checks before the merge; `--allow-unsigned` and `--no-sandbox` (root only). Prototype tests: 415 passed as user,
  427 under sudo. Details: [alp-trust-2026-11-10.md](../../verification/alp-trust-2026-11-10.md).
- `scripts/rebuild/trust/`: `make-temp-signing-key.sh`, `integrate-trust.sh`, `iso-gate.sh`.
- `build-iso.sh` calls `iso-gate.sh --auto` on its writable copy.
- r10, r11 and r3 scripts: `--allow-unsigned` with the demo index only when the alp.py they run knows it.
- `alpbahos-recover`: usage text names `pkexec /usr/local/sbin/alpbahos-recover` (your round 31 ESP lookup kept).

Behaviour after the merge, before anything else is done:

- `build-iso.sh` prints and logs (`$LOGS/trust-gate.log`) **"ALP-TRUST-01 henüz uygulanmadı: katalog imzasız"**
  and goes on. The decision comes from the root: no `alp-keyring` record in its alp database and the old
  `/usr/lib/alp/alp.py` installed = warning only.
- Once `integrate-trust.sh` has run on r4-root (it adds the `alp-keyring` record and the new alp.py), the same gate
  is strict by itself: no ISO without a signature that the image's own alp accepts. A half-done state (keyring
  record but no signature, or keyring record but the old alp.py) also fails.
- Evidence: [soft-gate.log](../../verification/alp-trust-integration-2026-11-11/soft-gate.log) (read-only snapshot
  of r4-root: warning, rc 0; integrated copy: PASS; broken copies: FAIL).
- The repo `alp.py` (used by r10/r11/apply-r7 on the host) becomes the new engine at merge time. `adopt-base`,
  `list` and `check` with the demo index keep working (tried: 546/550 packages, rc 0). A script that calls the repo
  alp.py with an unsigned index and is not in the list above would now be refused; grep found no other.

To switch it on for real (in this order; one writer on r4-root at a time):

1. Keys. The only keys that exist are **temporary build keys** in `scratch-lfs-bench/alp-signing/` (no passphrase;
   never commit, never copy into an image). Their permanent home is the user's decision (D173); replace them
   before any release. To make them on another host: `bash scripts/rebuild/trust/make-temp-signing-key.sh`.
2. `sudo ALLOW_LIVE_R4=1 bash scripts/rebuild/trust/integrate-trust.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root /home/yrslf/alpbahOS/scratch-lfs-bench/r4-ledger/trust 1`
   (records `alp-build-user`, `alp-keyring`, `alp`, `alp-catalog`; then `alp list/check/search` in a chroot).
3. `sudo bash scripts/rebuild/trust/iso-gate.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root` -> PASS.
4. Every later change of `/usr/share/alp/index.json` (for example `make-catalog-r8.py`): run step 2 again with the
   next catalog version (2, 3, ...). Otherwise the gate stops the ISO.
5. Build the ISO, then QEMU: `alp list/check/search` rc 0 live and installed; a changed catalog refused; a recipe
   build on the booted system; Discover.

The same steps were tried on a snapshot copy, `scratch-lfs-bench/r4-trust-probe` (kept):
[alp-trust-integration-2026-11-11.md](../../verification/alp-trust-integration-2026-11-11.md).

Sandbox finding: bubblewrap **does not work in a plain chroot** ("No permissions to create a new namespace"). It
works when the root is entered with pivot_root (`bwrap --bind ROOT / --dev /dev --bind /proc /proc ...`, or
nspawn). An `alp install` of a recipe inside a chroot therefore needs `--no-sandbox` (root, warns every time) or a
pivot_root entry. Today's image build uses `adopt-base`, not recipes, so this does not bite yet.

Not done: integration of the live r4-root; ISO; QEMU; real keys; full runs of the r10/r11/r3 scripts; a re-signing
hook in `make-catalog-r8.py`; GitHub workflow run.

Next single action: merge the branch (ISO builds keep working, with the warning), then decide when to run step 2.
