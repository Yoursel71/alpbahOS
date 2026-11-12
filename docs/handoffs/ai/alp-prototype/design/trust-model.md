# alp trust model: signed catalog and unprivileged builds (design note, C9)

Status: **accepted by the user 2026-11-10 (D170); implemented in the prototype** (`alp.py`, branch
`ai/alp-trust-2026-11-10`), **not yet in any image**. Record:
[alp-trust-2026-11-10.md](../../../../verification/alp-trust-2026-11-10.md). BACKLOG: ALP-TRUST-01.
The four open questions of section 8 have default answers (D171-D174) that the user can change; section 9 lists
where the code differs from this note. The text below is the note as reviewed, with rule 3 of section 3.3 and the
`valid_until` window updated to D172.

## 1. Problem

Today (alp.py as of commit `264050a`, 267 tests pass):

- The catalog (`index.json` plus the recipe JSON files it names) is not signed. `alp update` accepts any https or
  local source; a git catalog is pulled as is. Only the source tarballs are checked, by the sha256 the catalog itself
  gives, so whoever can change the catalog can also change the hashes.
- Recipe steps (`configure`, `make`, `make install DESTDIR=...`) run with `subprocess.run` as the user who runs alp,
  which is root for a system install. A recipe step can write anywhere and reach the network.

So control of the catalog (repository, mirror, CDN, a local file someone swapped) means root on every machine that
runs `alp update` and then installs or upgrades a package.

Kept as they are (they are sound): the journaled merge with rollback, the two-phase database write, `safe_extract`,
no `shell=True`, protected paths, ownership checks, the transaction lock.

## 2. Threats in scope

| Threat | Covered by |
|---|---|
| Changed catalog on the server, a mirror or in transit | signature on the catalog (3) |
| Old but validly signed catalog replayed to hide a security update (rollback), or the same old catalog served forever (freeze) | monotonic catalog version and an expiry date inside the signed data (3.3) |
| A swapped local catalog file (`/usr/share/alp/index.json`) | the same signature check before every use, not only at `alp update` (3.4) |
| A build step that tries to change the system while building | unprivileged, network-less build in its own directory (5) |
| A staged tree with surprises (setuid files, device nodes, paths outside the prefix) | root-side checks before the merge (6) |

Not covered (said plainly): a malicious recipe that **we** signed. The sandbox stops it at build time, but the files
it installs run as root later (a systemd unit, a setuid helper the recipe declares). Only review and the signing key's
protection cover that. Compromise of the signing key is handled by rotation and revocation (4), not prevented.

## 3. Signature scheme

### 3.1 Format

- Tool: **OpenPGP detached signatures checked with `gpgv`** (GnuPG 2.5 is already in the image for Flatpak). `gpgv`
  checks against a fixed keyring file and has no trust database; this is the model apt uses. alp calls it with
  `subprocess.run([... "gpgv", "--status-fd", "1", "--keyring", <file>, <sig>, <data>])`, no shell, and accepts the
  result only on a `VALIDSIG <fingerprint>` status line whose fingerprint is in the allowed list (3.2). The exit code
  alone is not trusted.
- Key type: Ed25519 (small signatures, supported by GnuPG 2.5).
- Alternative considered: OpenSSL Ed25519 raw signatures (`openssl pkeyutl -verify -rawin`). Simpler key files, but
  no expiry or revocation format; we would have to invent both. Rejected for that reason.

### 3.2 What is signed

- One file is signed: `index.json`, with a detached `index.json.sig` next to it.
- `index.json` gains fields, all inside the signed bytes:
  - `catalog_version`: an integer that only grows;
  - `valid_until`: an ISO date (90 days after signing, D172; the note first proposed 30);
  - `signed_keyring_version`: the keyring version it expects (4);
  - for every package entry, `recipe_sha256`: the sha256 of the recipe JSON file it names.
- Recipes already carry the sha256 of their source tarball. So one signature covers the whole chain:
  index -> recipe -> source.
- A bundle (`.tar`) or a git checkout is only a transport. alp verifies `index.json` + `.sig` after unpacking or
  pulling, before the new catalog replaces the old one.

### 3.3 Rules alp applies

1. Signature valid and made by an allowed, unrevoked key: otherwise refuse, keep the old catalog, Turkish error.
2. `catalog_version` >= the last version alp accepted (stored in the alp database): otherwise refuse (rollback).
3. `valid_until` not in the past: otherwise `alp update` refuses the new catalog (freeze). The catalog already on
   disk is still used after `valid_until`: alp warns "katalog süresi doldu ... `alp update` çalıştırın" on every
   command and goes on, as long as rules 1 and 2 hold (D172; the first version of this note refused here). Reason:
   the image ships a signed snapshot and must be able to install offline.
4. Each recipe file's sha256 equals `recipe_sha256` before the recipe is read.

### 3.4 When it is checked

At `alp update` (the new catalog), and **again every time a catalog is loaded for an install, upgrade or
`alp check`**. A local file swapped after the update then fails the next use, not only the next update. The cost is
one `gpgv` call per command (milliseconds).

## 4. Keys: location, rotation, revocation

- **Image:** the public keys are in `/usr/share/alp/keys/alpbahos-catalog.gpg` (binary keyring) with
  `/usr/share/alp/keys/allowed.txt`, which lists the fingerprints that may sign catalogs and the revoked ones. Both
  come from an alp package `alp-keyring`, owned and checked like any other package.
- **Private keys** never touch the repository, CI or the build host's normal user account. Proposal:
  - the current signing key lives on a hardware token or an offline machine of the user;
  - a second, backup key is made at the same time, shipped in the first keyring as allowed, and stored offline
    separately.
- **Rotation, planned:**
  1. A new `alp-keyring` version that adds the new key is published in a catalog signed by the old key.
  2. Once machines have it (one `valid_until` period), catalogs are signed by the new key.
  3. A later keyring version drops the old key.
- **Revocation, after a key loss:** the backup key signs a catalog whose `alp-keyring` update marks the lost key's
  fingerprint as revoked. alp applies a keyring update before it trusts anything else in that catalog: the keyring
  package is installed first, then the catalog is checked again with the new keyring.
- **Machines that missed several rotations:** if no key in their keyring can check the new catalog, alp refuses.
  The fix is a manual step (install a newer `alp-keyring` from the alpbahOS release page or a newer ISO). This is
  documented, never automatic.

## 5. Unsigned local catalogs

- By default an unsigned catalog is refused, for every command.
- For development and tests only, `--allow-unsigned` (root only):
  - accepts a catalog without `.sig`;
  - prints a red Turkish warning on every run;
  - is never accepted by the PackageKit backend (Discover), which always requires a signed catalog;
  - is never written into a configuration file, so it does not stick.
- The test suite and the demo catalog use either `--allow-unsigned` or a test key generated in the test's temp dir
  (never committed as a private key).
- The image ships a signed catalog snapshot, so a fresh install works offline.

## 6. Builds without root, merge with root

### 6.1 Build as an unprivileged user in its own directory

- **Build user:** a system user `alpbuild` (no login shell, no password, no home outside the build area).
- **Download:** alp downloads the source as root into `/var/lib/alp/build/<transaction>/` and checks the sha256 from
  the signed recipe. Only then does the directory get `chown -R alpbuild:alpbuild`.
- **Running the steps:** `bwrap` (bubblewrap, already in the image for Flatpak; `CONFIG_USER_NS=y`) runs each step
  as `alpbuild`:
  - `/` bound read-only;
  - only the transaction's source and staging directories writable;
  - a private `/tmp`;
  - `--unshare-net` (no network while building), `--unshare-ipc`, `--unshare-pid`, `--die-with-parent`,
    `--new-session`;
  - an empty environment except `PATH`, `HOME` (the build dir), `LC_ALL=C`, `MAKEFLAGS`, `SOURCE_DATE_EPOCH`.
- **Changing to the build user:** alp, as root, starts bwrap through a small helper that changes to `alpbuild`. The
  helper sets `no_new_privs`, drops supplementary groups and uses `setresgid`/`setresuid` (Python `os.set*`) before
  exec. util-linux `setpriv` is not in the image.
- **Second layer:** Landlock is in the kernel's LSM list (`CONFIG_LSM` has `landlock`). The helper can restrict
  writes to the two directories even if a bwrap bind were wrong. Proposed, and optional for the first version.
- **Fallback:** if bwrap cannot start (no user namespaces, a container), alp refuses to build from source unless
  root passes `--no-sandbox`, which prints a warning. It never falls back silently.

### 6.2 Merge as root, after checks

- **Checks before the merge**, extending today's `_preflight_merge`. The staged tree is refused when:
  - an entry is outside the allowed prefixes;
  - an entry is a device node, socket or FIFO;
  - an entry is a hard link to outside the stage;
  - a symlink points outside the root;
  - a file is setuid or setgid and is not listed in the signed recipe's new `setuid` list.
- **Normalising:** ownership becomes `root:root` (the staged files belong to `alpbuild`). Modes are kept, except
  group/other write is dropped from files under `/usr`.
- **Merge:** the existing journaled merge, as root, unchanged. The rollback and the two-phase database write stay
  exactly as they are.

## 7. Tests (acceptance for the implementation)

- A tampered catalog: one byte changed in `index.json`, or in a recipe file whose `recipe_sha256` no longer
  matches. Refused, the old catalog stays.
- A missing signature: refused, unless `--allow-unsigned`.
- A signature by a key that is not in the keyring, or by a revoked key: refused.
- An older `catalog_version` than the last accepted one: refused. An expired `valid_until`: refused at
  `alp update`, warning at local use (D172).
- A build step that tries to write outside its build dir (`/etc/x`, `/usr/bin/x`, `$HOME/x` of root): the step
  fails and nothing outside the stage changes.
- A build step that tries to use the network: it fails.
- A staged setuid file not listed in the recipe: the merge is refused.
- All existing tests still pass (267 at the time of writing; the task text said 266).

## 8. Open questions for the reviewer

1. gpgv (OpenPGP) or a minimal Ed25519 format, given that we need expiry and revocation?
2. Is 30 days the right `valid_until` window for schools that are offline for weeks? A longer window weakens freeze
   protection.
3. Where should the private key live (hardware token or offline machine), and who holds the backup key?
4. Is refusing source builds without a sandbox (6.1, last bullet) acceptable, or should binary-only installs be
   the only path for end users?

Default answers taken on 2026-11-10 (open to the user's change): 1 -> D171 (gpgv); 2 -> D172 (90 days, warning at
local use); 3 -> D173 for the public side, the private key's home is still open; 4 -> D174 (refuse, `--no-sandbox`
for root).

## 9. Implementation notes (2026-11-10)

Where the code is stricter than, or different from, the text above:

- **Same bytes verified and parsed.** `index.json` and `index.json.sig` are read once; gpgv gets the data on stdin
  and the signature and keyring through anonymous descriptors (`memfd`); the JSON parser runs on the same bytes.
  Recipes are read once, hashed, and the same bytes parsed.
- **Signature rules beyond 3.1:** exactly one signature; binary class (00) only; SHA-256/384/512 only; gpgv and
  bwrap are taken from fixed paths, not `PATH`; gpgv runs with an empty environment and a non-existent home.
- **`allowed.txt`** names primary-key fingerprints; `revoked` matches the primary key or the signing subkey.
- **`signed_keyring_version`** is checked for type and compared with `keyring-version` in `allowed.txt`; a catalog
  that expects a newer keyring prints a hint and is still accepted (it is how the keyring update arrives). The
  "install `alp-keyring` first, then check again" step of section 4 is **not implemented**; it needs the package.
- **Bundles:** only files the accepted index names are installed, each checked against the sha256 the index pins.
  Everything else in the archive is ignored. Before, every file was copied, which would have let a sender add a
  keyring next to a genuine signed index.
- **Git catalogs:** the fetched commit is verified from the object store (`git show`) before the fast-forward, and
  again from the files after it. alp refuses a git update when the keyring or `allowed.txt` is inside the checkout.
- **`alp update` with an unusable local catalog** still runs (it is the way out), but then takes nothing from the
  local catalog: the source must be given with `--source`. `alp recover` needs no catalog at all.
- **Rollback floor at update** is the higher of the stored version and the verified local catalog's version, so a
  fresh install is protected before anything was stored. An unsigned catalog never changes the stored version.
- **Sandbox:** `/run` is also a private tmpfs (its sockets reach D-Bus, resolved and nscd, which a network
  namespace does not close); `--unshare-uts` is added. The build tree stays in `var/lib/alp/cache/` (the note said
  `var/lib/alp/build/<transaction>/`). `MAKEFLAGS` is `-j<--jobs>` (default 1) and nothing is inherited from the
  caller's environment, also with `--no-sandbox`.
- **Ordinary users:** alp run by a non-root user starts bubblewrap directly, with no privilege drop (there is
  nothing to drop). `--no-sandbox` and `--allow-unsigned` are refused for non-root.
- **Stage checks:** allowed top-level directories are `usr etc var opt boot srv bin sbin lib lib32 lib64 libx32`;
  `var/lib/alp` and `var/log/alp` are refused. "Symlink outside the root" is decided lexically: a relative target
  that climbs above the root, or, for a `--relocate` build, an absolute target outside the root. A hard link is
  refused when the inode has more names than the stage holds. The setuid/setgid check covers directories too.
  Core archives get the same checks with an empty setuid list.
- **Normalising (changed after the coordinator review of 2026-11-11):** group and other write are dropped from
  every staged file and directory, not only under `/usr` as section 6.2 says. The one exception is a directory
  with the sticky bit (for example `var/tmp` 1777). A recipe cannot ask for another exception, and a sticky
  world-writable directory needs no listing in the recipe; an explicit recipe list for such directories was
  considered and left out (it would be a second allow-list next to `setuid` for a case no current recipe has).
- **Rule 4 (changed after the same review):** every entry that has a `recipe` field needs `recipe_sha256`,
  whatever its `method`; entries of a signed catalog are marked (`SignedEntry`) and a recipe is never read for a
  marked entry without a digest.
- **Landlock:** not implemented (section 6.1 called it optional).
