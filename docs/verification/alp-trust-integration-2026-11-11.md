# ALP-TRUST-01 step 3 trial: merge branch and image integration on a copy of r4-root, 2026-11-11

Follows [alp-trust-2026-11-10.md](alp-trust-2026-11-10.md). Done by a Claude sub-agent on the coordinator's
instruction. Host `thewo`. Branch `claude/integ-alp-trust-2026-11-11`, worktree `/home/yrslf/alpbahOS/wt-integ`,
started from `ba7de06` (= `yoursel/main` after `git fetch`). Not pushed.

**State: scripts written and tried on a snapshot copy of r4-root. Not applied to the live r4-root. No ISO built,
no QEMU run, nothing booted.** The live `r4-root`, the ISOs, the main worktree and the other session's VMs were not
touched (two read-only actions on r4-root: `btrfs subvolume snapshot` twice, see sections 2 and 5).

**The signing keys used here are TEMPORARY BUILD KEYS** (section 3). They are unprotected files on the build host.
Where the real key lives (hardware token or offline machine) and who holds the backup is the user's decision
(D173). They must be replaced before any release.

## 1. Merge branch

| Step | Result |
|---|---|
| `git merge --no-ff claude/alp-trust-2026-11-10` | one conflict, `docs/DECISIONS.md`: both sides added rows after D154. Kept both: main's D155-D162, then D170-D174 (none of D170-D174 was used on main; no renumbering). `docs/BACKLOG.md` merged by git without conflict. Commit `efe711b` |
| `git merge --no-ff claude/matrix-r21-2026-11-10` | clean (one new file). Commit `b2975a7` |
| alp prototype on main since `dc78ce9` | `git diff dc78ce9 ba7de06 -- docs/handoffs/claude/alp-prototype .github/workflows/alp-tests.yml`: empty. Nothing to reconcile |
| Handoff number | 039 was free on main (035 is its newest) |
| `CURRENT.md` | ALP-TRUST-01 and round 21 matrix entries added (`d0f4a81`) |

Tests on the merged branch (host, no VM), before the script changes of section 4:

| Run | Result |
|---|---|
| `python3 -m pytest tests -q` in the prototype dir, user `yrslf` | 415 passed, 17 skipped |
| same under `sudo` | 427 passed, 5 skipped |
| `python3 -m pytest tests --ignore=tests/legacy -q` (repo) | 89 passed |
| `python3 -m pytest profiles -q` | 15 passed |
| `check_docs.py` (after this record was added) | 0 findings |

## 2. Probe copy and what was tried in it

Copy: `sudo btrfs subvolume snapshot scratch-lfs-bench/r4-root scratch-lfs-bench/r4-trust-probe` (writable
snapshot; r4-root is a btrfs subvolume and had nothing mounted under it). `btrfs filesystem du -s`: 107.50 GiB
referenced, **14.12 MiB exclusive**. **The copy is kept** for the next step.

Tools in the copy: `/usr/bin/gpgv` and `gpg` (GnuPG) 2.5.21, bubblewrap 0.13.1 (not setuid), Python 3.14.7, gcc,
make; no git, no pytest. The image catalog has 470 entries, all `lfs-base`, no recipes.

| # | Tried | How | Result | Log |
|---|---|---|---|---|
| a | The image's gpgv with keyring and signature as `/dev/fd` memfds | plain chroot (proc, sys, dev, tmpfs mounted, then unmounted), the copy's python3 running `verify_catalog_signature` with a throwaway key made by the copy's gpg | good signature accepted; changed data refused; changed signature refused; `accept_catalog_bytes` signed | `probe-ab.log` |
| b | bubblewrap in a **plain chroot** of the copy | `_prepare_sandbox` as root, build ids 65534 | **refused**: "bwrap: No permissions to create a new namespace". The kernel does not let a chrooted process create a user namespace | `probe-ab.log`, `e2e.log` |
| b' | bubblewrap when the copy is entered with **pivot_root** | host `bwrap --bind COPY / --dev /dev --bind /proc /proc ...` as the outer container, then `_prepare_sandbox` inside | **works**. (With `--proc /proc` instead of `--bind /proc /proc` the inner bwrap fails: "Can't mount proc on /proc") | `probe-b-pivot.log` |
| c | The whole alp test suite with the copy's python3, gpg, gpgv and bwrap | pytest is not in the image; the host's pytest files were put on `PYTHONPATH` in a temp dir bound at `/tmp`; root inside the pivot_root container | **414 passed, 18 skipped** (13 need git, 5 need a non-root user); the root-only sandbox tests ran | `probe-c.log` |

Consequence for image builds: a build step that runs `alp install` of a **recipe** inside a plain `chroot` cannot
use the sandbox. Options, to be chosen at step 3: (1) enter the root with pivot_root (as in b'; `systemd-nspawn`
or bwrap) instead of chroot; (2) pass `--no-sandbox` (root, warning on every build) for chroot builds; (3) build
from the host with `--root`. Today the image is built with `adopt-base` records, not recipes, so nothing breaks
now. On a booted system there is no chroot, so the sandbox should work there; **not tested** (needs QEMU).

## 3. Integration scripts (`scripts/rebuild/trust/`)

| Script | What it does |
|---|---|
| `make-temp-signing-key.sh` | makes `scratch-lfs-bench/alp-signing/` (mode 700, outside the repository): two GnuPG homes (primary, backup; Ed25519, no passphrase), the public keyring with both keys, `allowed.txt`, `FINGERPRINTS`. Refuses an existing directory and a path inside a worktree |
| `integrate-trust.sh <ROOT> <LEDGER> [VERSION]` | four alp records, in this order: `alp-build-user` (`/usr/lib/sysusers.d/alp-build.conf`, then `systemd-sysusers --root`), `alp-keyring` (public keyring and `allowed.txt`, root:root 644; refuses a keyring with a secret key), `alp` (new `/usr/lib/alp/alp.py`, taking the file over), `alp-catalog` (stamped `index.json` + `index.json.sig`). Then `alp list/check/search` in a chroot. **Refuses the live r4-root unless `ALLOW_LIVE_R4=1`** |
| `iso-gate.sh <ROOT>` | exit 0 only if: installed alp.py has the signature check; keyring, `allowed.txt`, index and signature exist, root:root, not group/other-writable; no secret key files under `/usr/share/alp`; `alpbuild` exists with a locked password; the root's own `alp list` accepts the catalog and does not warn about expiry; the same alp refuses a copy with one changed byte |

Temporary key fingerprints (public information; made 2026-11-11, `signing-key.log`):

- primary `3421D4077D20373C547AD79959CADCB70E2EB50E`
- backup  `CBF059A0185CE8CBE7DB4074662A5C22D8D8AFE5`

Run on the copy (`integrate.log`): `alpbuild:x:998:998:alp build user:/:/usr/sbin/nologin`, shadow entry locked;
records `alp-build-user 0.9-trust1`, `alp-keyring 1-temporary`, `alp 0.9-trust1`,
`alp-catalog 2026.11.11-trust1`; catalog stamped `catalog_version=1 valid_until=2027-02-09
signed_keyring_version=1`; in the chroot `alp list` rc 0 (546 lines), `alp check` rc 0, `alp search bash` rc 0;
0 mounts left. Ledger: `scratch-lfs-bench/alp-trust-probe-ledger/`.

## 4. End to end on the copy (`e2e.log`, `adapted-callers.log`)

| Check | Result |
|---|---|
| `iso-gate.sh` on the integrated copy | PASS, rc 0 (before and after the other checks) |
| `iso-gate.sh` on a pristine read-only snapshot of r4-root (`r4-trust-gate-neg`, deleted right after) | FAIL "installed alp.py has no signature check", rc 1 |
| Installed `alp list`, `check`, `search bash`, signed catalog | rc 0 each (the first three lines of `e2e.log` show a harness error instead: the output file was not writable; the three commands were run again, see the end of `adapted-callers.log`, and `integrate.log` has them too) |
| One byte of `/usr/share/alp/index.json` changed, then restored | `list`, `check`, `search`: rc 1, "Katalog imzası geçersiz: imza katalogla uyuşmuyor" |
| `index.json.sig` removed, then restored | rc 1, "Katalog imzalı değil"; with `--allow-unsigned` as root: warning printed, works |
| Source build from a small signed test catalog (`alp-hello`: one C file and a Makefile, local source, **no network**; signed with the temporary primary key), inside the pivot_root container | rc 0. Build log: `[bwrap, uid 998; MAKEFLAGS=-j1 ...]`; the file written during `make` says uid 998 = `alpbuild`; installed `/usr/bin/alp-hello` root:root 755 runs and prints `alp-hello 1.0`; then removed with `alp remove` |
| The same install in a plain chroot | rc 1, refused: bubblewrap cannot create a user namespace (finding b) |
| Recipe changed after signing | install rc 1, "Tarif dosyası katalogdaki özetle uyuşmuyor", nothing installed |
| Database of the copy | `catalog: {version: 1, signer: 3421...B50E}` stored by the install |
| demo htop recipe | not tried: it needs the network and its sha256 is a placeholder |

## 5. Callers of alp with the unsigned demo index (`grep` over `scripts/`, without `legacy`)

| File, line | Before | Now (this branch) |
|---|---|---|
| `scripts/rebuild/r10/pkg-step-r10.sh` 23, 25 | `sudo python3 .../alp.py --root "$R4" --index .../demo/index.json check` / `list` | `--allow-unsigned` added (root; repo alp.py of the same checkout) |
| `scripts/rebuild/r11/pkg-url-r11.sh` 33, 35 | same | same |
| `scripts/rebuild/r3/run-r3.sh` 145 | `python3 "$ALP_PY" --root "$R3ROOT" --index "$INDEX" list` | `--allow-unsigned` added |
| `scripts/rebuild/r3/image-alp-check.sh` 34, 41 | `chroot "$M" /usr/bin/alp --index /run/alp-index.json list` / `check` (the alp **installed in the image**) | passes `--allow-unsigned` only if the installed `alp.py` contains the option, so it works with old and new images |
| `scripts/rebuild/r13/r13-records.sh` 67, 68 | `chroot "$R4" /usr/bin/alp list` / `search` (no `--index`) | not changed: works once the root has the signed catalog; refused on a root with the new alp.py and no signature |
| `scripts/rebuild/r7/apply-r7.sh`, `r4_lib.py` | `adopt-base` and module import only | not changed: `adopt-base` reads no catalog |

Tried against the copy: the adapted r10/r11 line gives `check` rc 0 and 546 packages; the unadapted line with the
new alp.py is refused ("Katalog imzalı değil"); the adapted line with the **old** alp.py (main worktree, read
only) fails with "tanınmayan argüman: --allow-unsigned". So scripts and `alp.py` must change in the same checkout,
which a merge does. Not run: the full r10/r11/r3 scripts themselves (they build packages or need an image).

`build-iso.sh`: the gate runs on the writable copy right after the two snapshots; on failure both snapshots are
deleted and the build stops with a pointer to `integrate-trust.sh`. `bash -n` passes. **`build-iso.sh` was not run.**
Effect on the other session: after this branch is merged, `build-iso.sh` refuses to build until r4-root has been
integrated (step list below). That order is intended and must be agreed before merging.

## 6. Steps to apply to the live r4-root (not done), in order

1. Decide the key question (D173) or accept the temporary keys for test images only.
2. Stop every other writer on r4-root (one writer at a time); nothing mounted under it.
3. Merge this branch (scripts and `alp.py` together).
4. `sudo ALLOW_LIVE_R4=1 bash scripts/rebuild/trust/integrate-trust.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root /home/yrslf/alpbahOS/scratch-lfs-bench/r4-ledger/trust 1`
5. `sudo bash scripts/rebuild/trust/iso-gate.sh /home/yrslf/alpbahOS/scratch-lfs-bench/r4-root` (it mounts and unmounts proc and dev there and writes a temp dir under `var/tmp`).
6. Whenever the catalog is regenerated (`scripts/rebuild/r8/make-catalog-r8.py`) or changed: run step 4 again with
   the next catalog version (2, 3, ...). Signing is the last step before `build-iso.sh`; the gate catches a
   forgotten re-signing.
7. Build the ISO; then QEMU: `alp list/check/search` rc 0 in the live and the installed system; a changed catalog
   refused; a recipe build as `alpbuild` in bubblewrap on the booted system; Discover/PackageKit against the
   signed catalog.

## 7. Section C items from the round 21 matrix record

| Item | Finding in this tree | Action |
|---|---|---|
| zram stop: `swapoff` EINVAL at shutdown | Already fixed on main in round 30 (`scripts/rebuild/r21/product-r21.py`, stop branch treats "no longer an active swap" as done; `scripts/rebuild/r30/zram-stop-r30.sh`). Cause as recorded there: systemd's own `dev-zram0.swap` unit had already turned the swap off | none; not changed again |
| `target-initramfs.sh` `echo "$LIST" \| grep -q` EPIPE | Already fixed on main in round 30: no such pipe left under `scripts/rebuild/iso` (`grep` count 0) | none |
| `alpbahos-recover` usage says `sudo alpbahos-recover` | Still so on main. In the live session the user has no password and `/usr/local/sbin` is not in `PATH`; `pkexec /usr/local/sbin/alpbahos-recover` works without a prompt (round 21 REC1/REC2) | usage text, comment and the "run as root" message now name the pkexec call (`571f31c`). Smaller than adding a sudo rule or a PATH entry to the live image. `sh -n` passes; the message was printed once on the host. **Not rebuilt into an ISO.** RECOVER-UX-01 stays Partial (no launcher) |
| alsa-utils | BACKLOG row AUDIO-TOOLS-01 already exists on main (recorded in round 30) | none |

## 8. Not done, and what stays on disk

Not done: live r4-root integration; ISO; QEMU; real signing key; `build-iso.sh` run; the r10/r11/r3 scripts run in
full; a decision between pivot_root and `--no-sandbox` for chroot recipe builds; rotation of the catalog version
in `make-catalog-r8.py`; GitHub workflow run.

On disk under `/home/yrslf/alpbahOS/scratch-lfs-bench/` (none in the repository):

- `r4-trust-probe/` : the integrated copy (btrfs snapshot, 14 MiB exclusive at the time of writing). Kept.
- `alp-signing/` : temporary keys, mode 700, 52 KiB. Kept. Never commit, never copy into an image.
- `alp-trust-probe-ledger/` (88 KiB), `alp-trust-probe-logs/` (32 KiB; copied into
  [alp-trust-integration-2026-11-11/](alp-trust-integration-2026-11-11/)).

Removed again: `r4-trust-gate-neg` snapshot; temp dirs under `/var/tmp`. Mounts: every script that mounted
something printed "mounts left under copy: 0"; `findmnt -rn -o TARGET | grep -c 'r4-trust\|wt-integ'` = 0 at the end.

## 9. Security points that are not settled

- The temporary keys have no passphrase and live in the build user's files: whoever can read that directory can
  sign catalogs that every test image accepts.
- `integrate-trust.sh` records the public keyring from `alp-signing/`; it checks only that no secret key packet
  is in it, not which keys are in it.
- `iso-gate.sh` trusts the root's own alp and gpgv to judge the root's catalog. A root with a tampered `alp.py`
  that still contains the string `verify_catalog_signature` and always answers 0 would fail only the negative
  control if it also accepted the changed copy; a more careful fake would pass. The gate is a build check against
  forgetting, not a defence against a hostile root tree.
- `systemd-sysusers` picked uid/gid 998 on the copy; on the live root the number may differ. Files are never
  owned by `alpbuild` after a merge, so the number is not stored in packages, but it is not pinned.
- The catalog directory `/usr/share/alp` holds the keys (`keys/`). That is safe for index and bundle updates
  (only pinned files are installed) and git updates are refused in that layout; a git-checkout catalog would need
  the keys elsewhere.
- Sandbox on a booted image: expected to work, not shown.

## 10. Harmless merge (2026-11-11, later)

The branch was brought up to `yoursel/main` `e8222c6` (merge commit `ac890d1`). One conflict, `docs/BACKLOG.md`
(ZRAM-STOP-01, AUDIO-TOOLS-01, RECOVER-UX-01, GREETER-01 rows): main's rows taken, and the RECOVER-UX-01 sentence
about the pkexec usage text added to main's row. `alpbahos-recover.sh` merged by git: main's round 31 ESP lookup and
this branch's pkexec usage text are both in. No new decision numbers on main after D162; D170-D174 unchanged;
handoff numbers 036 and 039 free on main.

Section 5 changed: `build-iso.sh` calls `iso-gate.sh --auto`. It warns ("ALP-TRUST-01 henüz uygulanmadı: katalog
imzasız") and lets the ISO build when the root has no `alp-keyring` record and the old alp.py; it is strict as soon
as either is present. The r10, r11 and r3 callers pass `--allow-unsigned` only when the alp.py they run has it.
Evidence in `soft-gate.log` (snapshots `r4-trust-old-ro`, read-only, of r4-root and `r4-trust-half`, writable, of the
copy; both deleted afterwards):

| Root | `iso-gate.sh --auto` |
|---|---|
| read-only snapshot of r4-root (never integrated) | warning, rc 0 (strict mode without `--auto`: FAIL, rc 1) |
| integrated copy `r4-trust-probe` | strict, PASS, rc 0 |
| copy with `index.json.sig` removed | strict, FAIL, rc 1 |
| copy with keyring record but the old alp.py | strict, FAIL, rc 1 |

| Caller form | New alp.py (repo) on the copy | Old alp.py (installed in r4-root, `bd8416f4…`) on the read-only snapshot |
|---|---|---|
| r10/r11 line (`check`, `list` with the demo index) | flag passed; check rc 0, 546 packages | flag not passed; check rc 0, 550 packages |
| image-alp-check.sh form (installed alp in a chroot) | flag passed; check rc 0 | flag not passed; check rc 0 |

Handoff for the other session: [036-alp-trust-merge-2026-11-11.md](../handoffs/claude/036-alp-trust-merge-2026-11-11.md).


## 11. Re-signing a regenerated catalog (2026-11-11, later)

Branch `claude/alp-resign-2026-11-11` (worktree `/home/yrslf/alpbahOS/wt-resign`, from `yoursel/main` `7cb38bd`).

Writers of `usr/share/alp/index.json` in `scripts/` (grep, without `legacy`): only `scripts/rebuild/r8/make-catalog-r8.py`
(writes `<STAGE>/usr/share/alp/index.json`) and step 4 of `integrate-trust.sh`. No chain script in this tree calls
`make-catalog-r8.py`; it was run by hand in round 8 (r4-root still has record `alp-catalog 2026.11.09-r8`).

New `scripts/rebuild/trust/resign-catalog.py <ROOT> <INDEX> [--signing DIR]` is the one place that decides and
signs. Rule: the same as `iso-gate.sh --auto` (alp-keyring record or the signed-catalog alp.py in ROOT). Not
applied: nothing is done (a stale `.sig` next to INDEX is removed). Applied: `catalog_version` = 1 + the highest of
ROOT's current `index.json`, ROOT's database (`catalog.version`) and INDEX; `valid_until` today + 90 days; every
`recipe_sha256` recomputed (recipes looked up next to INDEX, then in ROOT's `/usr/share/alp`); signed with the
temporary primary key; then checked with ROOT's own keyring and `allowed.txt`, the repo alp.py rules and the
rollback floor; `.sig` first, index last. Missing key, key not allowed by ROOT, signing or verification failure:
exit 1 with a Turkish/English message, INDEX untouched.

Callers: `make-catalog-r8.py` (optional third argument SIGNING_DIR; fails when the helper fails) and
`integrate-trust.sh` (its catalog-version argument is gone). New `record-catalog.sh <ROOT> <LEDGER> [SIGNING]`
regenerates and records `alp-catalog <date>-v<N>` (or `-unsigned`) with stage-record + transfer + adopt-base, so the
record's manifest holds the sha256 of exactly the new `index.json` and `index.json.sig`; `adopt-base` checks the
live files against it when it records. `alp_catalog_tool.stamp` now hashes every entry with a `recipe` field (the
rule of review fix 1) and can search several recipe directories.

Trials (`resign.log`, `resign-integrate.log`):

| # | Trial | Result |
|---|---|---|
| a | `record-catalog.sh` on the integrated copy `r4-trust-probe` | signed, `catalog_version` 2 (was 1), record `alp-catalog 2026.11.11-v2` with both files; `alp list` and `check` in the copy rc 0; `iso-gate.sh --auto` strict PASS |
| b | twice more in a row | versions 3 and 4, records `-v3`, `-v4`; list/check rc 0; gate PASS |
| c | wrong signing directory: helper alone, `make-catalog-r8.py`, `record-catalog.sh` | rc 1 each with the "imza anahtarı yok / no signing key" message; nothing recorded; the copy's catalog unchanged (cmp) |
| d | `make-catalog-r8.py` on a read-only snapshot of r4-root (never integrated; deleted afterwards) | rc 0, unsigned, no `.sig`, no `catalog_version`; entries = installed packages; `iso-gate.sh --auto` warning, rc 0 |
| e | `integrate-trust.sh` (new form) on a fresh writable snapshot of r4-root, then one `record-catalog.sh` (snapshot deleted) | old three-argument call refused with a usage line; integration rc 0 with `alp-catalog -v1`; regeneration gives `-v2`; gate PASS both times |

Not settled: the version floor knows only what this root has seen (its index and its database); two regenerations
on the same root at once are not locked against each other (one writer at a time, CLAUDE.md section 4);
`valid_until` is renewed at every regeneration.

## 12. Applied to the live r4-root (2026-11-11 10:38 +03:00) and host-side calls

The integration was run on the live r4-root by the coordinator (not by this agent), from `wt-resign` `ae11e8d`.
Summary of its log `scratch-lfs-bench/r4-ledger/trust-apply-2026-11-11.log` (read by this agent, not re-run):

| Step | Result |
|---|---|
| backup | read-only snapshot `scratch-lfs-bench/r4-snapshots/r4-before-trust-2026-11-11` |
| `alp check` before | rc 0, 550 packages |
| `integrate-trust.sh` | rc 0; `alp-build-user 0.9-trust1`, `alp-keyring 1-temporary`, `alp 0.9-trust1`, `alp-catalog 2026.11.11-v1` (catalog_version 1, valid_until 2027-02-09, temporary primary key); `alpbuild` 998:998 |
| chroot `alp list` / `check` / `search bash` | rc 0 (553 lines / 1 / 1) |
| `iso-gate.sh` strict, `--auto` | PASS, PASS |
| key files | root:root 644; no secret key in the root |
| mounts left | 0 |
| host `alp.py --root r4-root check` without key options | rc 1, "İzinli anahtar listesi okunamadı (/usr/share/alp/keys/allowed.txt)" |

The last row is by design (D173: trust anchors from the running system). Fix on branch
`claude/alp-hostkeys-2026-11-11`: `scripts/rebuild/trust/alp-host.sh`, used by every host-side call that loads a
catalog:

| File, line (before) | Change |
|---|---|
| `scripts/rebuild/r23/plymouth-r23.sh` 16 | `DONE=$(python3 .../alp.py --root "$R4" list 2>/dev/null \| cut -f1)` -> through `alp-host.sh`, stderr kept, stop with a message on an alp error or an empty list |
| `scripts/rebuild/r24/profile-welcome-r24.sh` 15 | same |
| `scripts/rebuild/r10/pkg-step-r10.sh` 28, 30 | `sudo python3 .../alp.py --root "$R4" $UNSIGNED --index demo ...` -> `sudo bash scripts/rebuild/trust/alp-host.sh .../alp.py --root ...` |
| `scripts/rebuild/r11/pkg-url-r11.sh` 38, 40 | same |
| `scripts/rebuild/r3/run-r3.sh` 149 | same form for `list` with the demo index |

Not changed: `adopt-base` calls (r3, r4, r5, r7, trust scripts), `r4_lib.py transfer/claim_symlinks`,
`stage-record-r8.py`, `alp-upgrade-record.py`, `temp01-reclassify.py`, `drop-live-medium-check.py` (database only,
no catalog), and the chroot calls (`r13-records.sh`, `image-alp-check.sh`, `iso-gate.sh`, `integrate-trust.sh`),
which use the root's own keys.

Trials (`hostkeys.log`; integrated root = a read-only snapshot of the live r4-root taken for the test and deleted
afterwards, old root = `r4-before-trust-2026-11-11`, read-only; new alp.py `7e7626b7`, old alp.py `bd8416f4` from the
old root):

| Call | integrated root, new alp | integrated root, old alp | old root, new alp | old root, old alp |
|---|---|---|---|---|
| DONE list (`list`, as root) | rc 0, 553 names | rc 0, 553 | rc 0, 550 (unsigned warning) | rc 0, 550 |
| r10/r11 `check` / `list` with the demo index | rc 0, 553 | rc 0, 553 | rc 0, 550 | rc 0, 550 |

Also: without the wrapper the new alp is refused on the integrated root (the finding); as an ordinary user the
wrapper call works on the integrated root (553 lines); the guarded DONE block (copied from plymouth-r23.sh, the same
text as in profile-welcome-r24.sh) goes on with 553/550 names and stops with "alp list failed on ...; stopping" when
alp fails (the old form also stopped under `set -euo pipefail`, but silently); the wrapper adds nothing for the
old alp.py on the integrated root beyond what it knows, `--allow-unsigned` on the old root, the key options on the
integrated root, and refuses a call without `--root` (rc 2). `plymouth-r23.sh` and `profile-welcome-r24.sh` were not
run as a whole.

