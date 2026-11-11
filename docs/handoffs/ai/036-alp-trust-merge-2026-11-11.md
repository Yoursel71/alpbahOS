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
2. `sudo ALLOW_LIVE_R4=1 bash scripts/rebuild/trust/integrate-trust.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root /home/yrslf/alpbahOS/scratch-lfs-bench/r4-ledger/trust`
   (records `alp-build-user`, `alp-keyring`, `alp`, `alp-catalog <date>-v1`; then `alp list/check/search` in a
   chroot). Since the re-signing branch it takes two arguments only; the catalog version is chosen automatically.
3. `sudo bash scripts/rebuild/trust/iso-gate.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root` -> PASS.
4. **Re-signing is automatic** (branch `claude/alp-resign-2026-11-11`): `make-catalog-r8.py` calls
   `scripts/rebuild/trust/resign-catalog.py` on the catalog it writes. On an integrated root it signs with
   `catalog_version` one above the highest the root has seen and `valid_until` 90 days ahead; if the key is missing
   or signing fails, `make-catalog-r8.py` fails, so no unsigned catalog is left for a signed root. On a root that
   is not integrated it does nothing. To regenerate and record in one step:
   `sudo ALLOW_LIVE_R4=1 bash scripts/rebuild/trust/record-catalog.sh <r4-root> <ledger dir>` (record
   `alp-catalog <date>-v<N>`). In this tree `make-catalog-r8.py` is the only writer of `usr/share/alp/index.json`
   (grep), and no chain script calls it today (the catalog record on r4-root is still `2026.11.09-r8`).
5. Build the ISO, then QEMU: `alp list/check/search` rc 0 live and installed; a changed catalog refused; a recipe
   build on the booted system; Discover.

The same steps were tried on a snapshot copy, `scratch-lfs-bench/r4-trust-probe` (kept):
[alp-trust-integration-2026-11-11.md](../../verification/alp-trust-integration-2026-11-11.md).

Sandbox finding: bubblewrap **does not work in a plain chroot** ("No permissions to create a new namespace"). It
works when the root is entered with pivot_root (`bwrap --bind ROOT / --dev /dev --bind /proc /proc ...`, or
nspawn). An `alp install` of a recipe inside a chroot therefore needs `--no-sandbox` (root, warns every time) or a
pivot_root entry. Today's image build uses `adopt-base`, not recipes, so this does not bite yet.

Not done (as of the re-signing branch; the live r4-root was integrated later, see below): ISO; QEMU; real keys; full runs of the r10/r11/r3 scripts; GitHub
workflow run.

Re-signing is ready, so applying step 2 to the live r4-root is now safe for later rounds: a regenerated catalog is
signed by the same command that writes it, and the gate stays green. Order: merge `claude/alp-resign-2026-11-11`,
then steps 2-3 on r4-root (one writer at a time), then the ISO.

## Applied to the live r4-root on 2026-11-11 at 10:38 (+03:00)

Done by the coordinator from `/home/yrslf/alpbahOS/wt-resign` (`ae11e8d`), log
`scratch-lfs-bench/r4-ledger/trust-apply-2026-11-11.log`:

- backup first: read-only snapshot `scratch-lfs-bench/r4-snapshots/r4-before-trust-2026-11-11`;
- `alp check` before: rc 0, 550 packages;
- `integrate-trust.sh` rc 0: records `alp-build-user 0.9-trust1`, `alp-keyring 1-temporary`, `alp 0.9-trust1`,
  `alp-catalog 2026.11.11-v1` (catalog_version 1, valid_until 2027-02-09, signed by the temporary primary key
  `3421D4077D20373C547AD79959CADCB70E2EB50E`); user `alpbuild` uid/gid 998; chroot `alp list` (553 lines), `check`,
  `search bash` rc 0;
- `iso-gate.sh` strict and `--auto`: PASS; key files root:root 644, no secret key in the root; mounts left 0.
- Finding in the same log: the repo alp.py run **from the host** with `--root r4-root check` is refused
  ("İzinli anahtar listesi okunamadı (/usr/share/alp/keys/allowed.txt)"). That is by design (trust anchors come from
  the running system, not from `--root`) and is handled by the rule below.

**From now on the next ISO's gate is strict:** no ISO unless r4-root's catalog is signed and accepted.

### Rule for running alp from the host against a build root

Use `bash scripts/rebuild/trust/alp-host.sh <alp.py> --root <ROOT> <command...>` (branch
`claude/alp-hostkeys-2026-11-11`), or pass `--keyring <ROOT>/usr/share/alp/keys/alpbahos-catalog.gpg --allowed-keys
<ROOT>/usr/share/alp/keys/allowed.txt` yourself. The wrapper adds those options when the root has the key files and
the alp.py knows them; for a never-integrated root (no keys, no `alp-keyring` record) run as root it adds
`--allow-unsigned`, so old roots and snapshots read as before. Inside a chroot of the root (`chroot R /usr/bin/alp`)
nothing is needed: the root's own `/usr/share/alp/keys` is used. Changed callers: `plymouth-r23.sh`,
`profile-welcome-r24.sh` (their DONE list now stops on an alp error or an empty list instead of going on silently),
`pkg-step-r10.sh`, `pkg-url-r11.sh`, `run-r3.sh`. `adopt-base`, `r4_lib.py transfer`, `stage-record-r8.py` and the
r5/r7 record scripts load no catalog and need nothing. Evidence:
[hostkeys.log](../../verification/alp-trust-integration-2026-11-11/hostkeys.log).

### Way back

`scratch-lfs-bench/r4-snapshots/r4-before-trust-2026-11-11` is r4-root just before the integration (read-only). To
go back, with no other writer active: move the current r4-root aside under a new name, then
`btrfs subvolume snapshot <backup> scratch-lfs-bench/r4-root` (a writable copy of the backup). Not tried.

### For the other session

Pull `yoursel/main` (with `claude/alp-hostkeys-2026-11-11` merged) before the next round. The ISO gate is strict
now. If a round changes `/usr/share/alp/index.json`, use `record-catalog.sh` (or `make-catalog-r8.py`, which
re-signs by itself). Call alp from the host only through `alp-host.sh` (or with the two key options).

Next single action: merge `claude/alp-hostkeys-2026-11-11`.
