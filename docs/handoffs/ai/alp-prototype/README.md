# `alp` prototype — run and test notes

This directory is the working evidence for the proposal in [../001-alp-hybrid-pkg-proposal.md](../001-alp-hybrid-pkg-proposal.md). `alp` is the package engine of alpbahOS (D122, which replaces v1 D31 and P13). The prototype and its system integration are not finished and not production-ready.

## Product decisions that apply here (v2, 2026-11-06)

Full list: [docs/DECISIONS.md](../../../DECISIONS.md). Live plan: [docs/MASTER_PLAN.md](../../../MASTER_PLAN.md) §5.

| ID | Decision (accepted by the user) | What it means for `alp` |
|---|---|---|
| D122 | Package engine is `alp`. | The CLI, the store and the base build share one engine, one database and one lock. |
| D123 | Commands `alp install`, `alp remove`, `alp update`; Turkish help and error messages; typing `apt install …` prints a hint that points to alp. | The apt hint is not implemented yet. |
| D124 | GUI store: KDE Discover through an alp PackageKit backend. | Design and draft status: [design/packagekit-integration.md](design/packagekit-integration.md). No working backend is tested yet. |
| D125 | Flathub is enabled by default. | Flatpak is an extra channel. It does not replace the base package system. |
| D126 | Stable channel; the user starts updates (no update notifications). | Upgrades run only when the user starts them. |
| D141 | During the rebuild, every base package is installed through `alp`, so the file-ownership ledger is created automatically. Replaces v1 D34. | The current test base uses the M04 adoption path below. The rebuild uses the D141 path. |

## Files

- `alp.py` — prototype CLI (Python 3.10+; tested with 3.14.7).
- `alp_catalog_tool.py` — maintainer-side helper for the signed catalog: `stamp` writes `catalog_version`, `valid_until`, `signed_keyring_version` and every `recipe_sha256` into `index.json`; `sign` runs `gpg --detach-sign`. alp never signs and does not import it.
- `design/trust-model.md` — signed catalog and sandboxed builds (ALP-TRUST-01, D170-D174).
- `demo/index.json` — sample catalog: one `recipe` entry (htop), one `flatpak` entry (firefox), one `core` entry (alpbah-theme-solid).
- `demo/recipes/htop.recipe.json` — sample build recipe. **The `sha256` field is a deliberate placeholder** (`REPLACE_WITH_REAL_UPSTREAM_SHA256_BEFORE_USE`); real htop version verification was not done.
- `demo/core/alpbah-theme-solid-1.0.0.tar.gz` — a few-hundred-byte fake theme archive made for testing only. It is not a real alpbahOS theme.

## Running

```bash
cd docs/handoffs/ai/alp-prototype
python3 alp.py --root /tmp/alp-test --index demo/index.json search alp
python3 alp.py --root /tmp/alp-test --index demo/index.json install alpbah-theme-solid
python3 alp.py --root /tmp/alp-test --index demo/index.json list
python3 alp.py --root /tmp/alp-test --index demo/index.json info alpbah-theme-solid
python3 alp.py --root /tmp/alp-test --index demo/index.json remove alpbah-theme-solid
```

`--root` replaces the real `/` with a DESTROOT. On alpbahOS the flag is omitted.

Since ALP-TRUST-01 (2026-11-10) alp refuses a catalog without a valid signature, so the demo catalog (unsigned in
the repository; no key is committed) needs one of the two ways in the next section first.

## Signed catalog and sandboxed builds (ALP-TRUST-01, 2026-11-10)

Design and decisions: [`design/trust-model.md`](design/trust-model.md), D170-D174. Evidence:
[`docs/verification/alp-trust-2026-11-10.md`](../../../verification/alp-trust-2026-11-10.md). Not in any image yet.

What alp checks, on every command that loads the catalog and again in `alp update` before anything is replaced:
`index.json.sig` is a good OpenPGP signature over `index.json` (checked with `/usr/bin/gpgv`) by a key listed in
`allowed.txt` and not revoked; `catalog_version` is not lower than the last version this system accepted;
`valid_until` (an expired new catalog is refused at `alp update`, an expired local one only warns); and each recipe
file matches its `recipe_sha256` before it is parsed.

| Option | Meaning |
|---|---|
| `--keyring FILE` | keyring to check against (default `/usr/share/alp/keys/alpbahos-catalog.gpg`) |
| `--allowed-keys FILE` | allowed and revoked fingerprints (default `/usr/share/alp/keys/allowed.txt`) |
| `--allow-unsigned` | accept a catalog with no `.sig`. Root only, warns on every run, cannot be stored, never used by the PackageKit backend. A signature that is present but bad is still refused |
| `--no-sandbox` | run recipe steps without bubblewrap. Root only, warns on every build, cannot be stored |
| `--jobs N` | `MAKEFLAGS=-jN` in the build environment (default 1) |

`/etc/alp/trust.conf` (root-owned) may set `keyring = /path` and `allowed_keys = /path`, nothing else. No
environment variable changes any of this. `allowed.txt`: one primary-key fingerprint per line, `revoked <fingerprint>`,
`keyring-version <n>`, `#` comments.

Running the demo catalog with a throwaway key (ordinary user; the key never leaves the temp dir):

```bash
cd docs/handoffs/ai/alp-prototype
T=$(mktemp -d); cp -r demo "$T/demo"; mkdir -m 700 "$T/gnupg"
gpg --homedir "$T/gnupg" --batch --pinentry-mode loopback --passphrase '' --quick-generate-key 'alp demo <demo@alp.invalid>' ed25519 sign never
FPR=$(gpg --homedir "$T/gnupg" --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
gpg --homedir "$T/gnupg" --output "$T/demo.gpg" --export "$FPR"; printf 'keyring-version 1\n%s\n' "$FPR" > "$T/allowed.txt"
python3 alp_catalog_tool.py stamp "$T/demo/index.json" --catalog-version 1 --keyring-version 1
python3 alp_catalog_tool.py sign "$T/demo/index.json" --homedir "$T/gnupg" --local-user "$FPR"
python3 alp.py --root "$T/root" --index "$T/demo/index.json" --keyring "$T/demo.gpg" --allowed-keys "$T/allowed.txt" install -y alpbah-theme-solid
gpgconf --homedir "$T/gnupg" --kill all; rm -rf "$T"
```

Or, as root only: `sudo python3 alp.py --root /tmp/alp-test --index demo/index.json --allow-unsigned search alp`.

Builds: recipe steps run inside bubblewrap (`/usr/bin/bwrap`) with `/` read-only, only the source and stage
directories writable, private `/tmp` and `/run`, no network, and only `PATH`, `HOME`, `LC_ALL`, `MAKEFLAGS`,
`SOURCE_DATE_EPOCH` in the environment. As root, alp first drops to the `alpbuild` user (must exist; no fallback).
A recipe may list `"setuid": ["/usr/bin/x"]`; any other setuid/setgid file in the staged tree, a device node, FIFO,
socket, hard link to outside the stage, symlink out of the root or a path outside the allowed directories stops the
merge before a file is written.

Tests: `python3 -m pytest tests/ -q` as an ordinary user, and `sudo python3 -m pytest tests/test_trust_sandbox.py -rs`
for the parts that need root (privilege drop, ownership; they build as uid 65534, no user is created).

## Tested in the first prototype environment (win32, Python 3.14.7, historical)

The original entry has no date. This was the Windows host, which is historical.

- `search` / `list` / `info` — worked.
- `core` method, full cycle: download (local file, resolved through `file://`), sha256 check, safe archive extraction, copy under `--root`, record in `db.json`, check with `list`/`info`, clean rollback with `remove`. All steps ran; the output is in section 8 of `001-alp-hybrid-pkg-proposal.md`.
- Single-writer lock: a second writer was rejected with a fake lock file.
- Checksum rejection: the `htop` recipe was downloaded from the real network (this host could reach the internet), compared with the placeholder sha256, did not match, and the run stopped safely.

## Not run in that environment

- Real `./configure && make && make install` — the host had no `make`/`configure` toolchain (`which make` returned nothing).
- Real `flatpak install`/`uninstall` — flatpak was not installed on that host.
- PackageKit/Discover integration — not written at that point; out of scope.
- Production run on a real alpbahOS rootfs with `--root /` — never tried, and should not be tried on the prototype (the real-system write path was never exercised).

This split follows the AGENT.md rule: untested builds, tests or hardware checks cannot be reported as done. The recipe and flatpak code paths are written correctly, but they had not been run with the real external tools at that point.

## Fixes after an independent review (2026-09-21)

asistan's independent code review found 3 problems, which were fixed (see [../003-alp-review-fixes.md](../003-alp-review-fixes.md)):

1. **`--dry-run` no longer touches the network or the disk.** In the earlier version, `fetch()` (download and checksum) ran unconditionally for `recipe`/`core` installs, before the `dry_run` check. That broke the CLI's own "touch nothing persistent" rule. Now dry-run returns early with no network request and no persistent file write. Retested: after `--dry-run install htop/firefox/alpbah-theme-solid`, `var/lib/alp/cache/` stays empty.
2. **Packages installed by the `recipe` method are now fully removed by `remove`.** `_merge_destdir` now records directories in `files[]` as well (before, only files were recorded, so directories created by `make install` stayed behind as orphans).
3. **A 30-second timeout was added to downloads** (`urllib.request.urlopen(..., timeout=...)`), so an unresponsive source cannot hang `alp install` forever.

The checksum-rejection test was rerun as a real (non-dry-run) `install htop` call. The behaviour is the same: a file that fails the checksum is deleted and the run stops.

## `upgrade` command and `--json` output mode (2026-09-21)

- **`alp upgrade <name>`** was added. It upgrades an installed `recipe`/`core` package to a new version and keeps config files like the `.pacnew`/`.pacsave` convention of Arch-family package managers (`.alpnew`/`.alpsave`). Design and status: [design/config-protection.md](design/config-protection.md). `upgrade` is refused for the `flatpak` method, because flatpak manages its own updates.
- **`--json`** was added for `search`/`list` (`info` already printed JSON), so a PackageKit backend or another tool can read the output without parsing text. Design: [design/packagekit-integration.md](design/packagekit-integration.md).
- **`alp_packagekit_backend.py`** was added. Its `alp_*` wrapper functions (they run the real `alp.py` as a subprocess and parse the JSON) **were really tested**. The `AlpPackageKitBackend` class itself could **not be imported or tested**, because the real `packagekit` module was not available on that host. The module docstring says so.

## Automated test set (2026-09-22, updated)

`tests/test_alp.py` and `tests/test_packagekit_backend.py` — pytest. They never reach the real network. On 2026-09-24, on Windows with Python 3.14.7 in a TTY PowerShell session, **82 tests passed and 10 POSIX-only tests were skipped**. Details: [`docs/verification/m02-alp-tests-2026-09-24.md`](../../../verification/m02-alp-tests-2026-09-24.md).

```bash
cd docs/handoffs/ai/alp-prototype
python3 -m pytest tests/ -v
```

## First real end-to-end test on Linux (2026-09-22)

`alp` was tested for the first time on a **real Linux environment**: the former Ubuntu build VM `alpbah-builder` (Ubuntu 24.04.5, over SSH, `sa@172.28.174.11`). Full details: [006-alp-real-linux-test.md](../006-alp-real-linux-test.md). Summary:

- **A real bug was found and fixed.** In the `recipe` method, `./configure` existed and was executable, but the run reported it as "not found". The cause: `shutil.which("./configure")` searched relative to the directory where `alp.py` ran, even though the step ran with `cwd=src_dir`. The new helper `_tool_available()` resolves the path against `src_dir`. This bug could only show up on a real Linux host where configure exists. On Windows `make` was missing anyway, so both causes gave the same message.
- After the fix, the `htop` recipe really ran `./configure`, and stopped on a real dependency error (`libncursesw` missing). This matches the prototype's own list of known gaps ("no dependency resolution"); it is not an `alp` bug.
- A **full `core` life cycle** (install → an unchanged config is silently upgraded → a changed config produces `.alpnew` without touching the user's file → `remove` keeps the changed config as `.alpsave`) was verified end to end on real Linux and matched the design.

The tests were checked for real regression value (not "always pass"). They were run against the `alp.py` version from before the fixes (`51f93b9`). **Exactly 7 tests failed, matching the 3 fixes**: 3 tests that check dry-run never calls fetch, 2 tests that check `_merge_destdir` records directories, and 2 tests that check the download timeout. The other 22 tests already passed.

Not covered (not run on that host, and marked in the tests): real `configure/make/make install`, real `flatpak install/uninstall`, and real downloads of `htop`/`jq`/`zsh`/`tmux` over the internet. Those were checked by hand in the `alpbahOS-alp` repository, not in this test set. This test set keeps the network mocked for speed and repeatability.

## Level 3 dependency checks (2026-09-23)

Details: [../013-alp-seviye3-deps.md](../013-alp-seviye3-deps.md). Summary:

- `depends` in `index.json` entries now takes version constraints: `"libfoo>=2.0"`, `"libfoo>=2.0,<3"` (a comma means AND). There is a new optional `conflicts` field.
- Install, upgrade and remove first show an **action plan**. In an interactive terminal they ask `[E/h]`; scripts and the PackageKit backend use `-y/--yes`.
- **Store contract (PKG-02, 2026-09-28):** `--json --dry-run install|upgrade|remove` gives the plan as one JSON object (steps, `problems`, `download_size`; exit code 1 when the operation would be refused). `--progress-fd N` writes one JSON progress event per line (`plan`, `step`, `phase`, `error`, `done`). Wrappers: `alp_plan`, `alp_updates`. Tests: `tests/test_store_contract.py`. Details: [design/packagekit-integration.md](design/packagekit-integration.md) §4.
- If a constraint or conflict would break in the plan, the operation is refused **before a single byte is written**.
- New commands and options:
  - `alp remove --cascade <name>`: removes the dependent packages too. Without `--cascade`, a package that another package needs cannot be removed.
  - `alp autoremove`: removes packages that were installed only as dependencies and are no longer needed by anyone.
  - `alp upgrade` (no name): upgrades all old packages. A pinned package is reported as "held back", and the others are upgraded.
  - `alp check`: lists broken constraints, conflicts, updates and orphaned dependencies in the installed system.
- `info` shows the installed package's `required_by` list, and `list` shows a "(dependency)" mark.
- Limit: each package has exactly one version in the catalog. So this is not a SAT solver; it is a deterministic constraint checker. System libraries outside the catalog are still Level 1 (`requires_commands` / `requires_libraries`).

Test results: on Windows **126 passed, 10 skipped**. On the builder (Ubuntu 24.04.5) **136 passed, 0 skipped**.

## M02 closure: rollback, recover, protected packages, update (2026-09-24)

- **Transactional rollback.** Each package install, upgrade and remove runs as one transaction. Before any file changes are **written**, the change is logged in `var/lib/alp/rollback/` (write-ahead) and backed up (hard link, or a copy when needed). If a file copy fails (disk full, I/O error, Ctrl-C) or a database write fails, every file goes back to its old state. Fixed rule: alp never writes files in place (temporary file + `os.replace`), so the backup keeps the old inode.
- **`alp recover`.** Rolls back a transaction that was cut short by `kill -9` or a power cut, using the log. While an unfinished transaction exists, `install/upgrade/remove/autoremove/update` are refused, and `alp check` shows the problem. A log that has the `commit` marker, written after the database was saved, is not rolled back.
- **`alp protect NAME` / `alp unprotect NAME`**, and `"protected": true` in a catalog entry. A protected package cannot be removed with `remove`, `--cascade` or `autoremove`. Ordinary protected packages can be upgraded. `method: "lfs-base"` records are also protected from upgrade, reinstall, remove and unprotect. `list --json` writes `"protected": true` only when the package is protected (the JSON contract does not change).
- **`alp update [--source URL|PATH] [--sha256 HEX]`.** The source is an `index.json` or a `.tar.gz` catalog package with `index.json` at its top. The `"source"` field in `index.json` is the default source. `http://` is refused. The new catalog is validated (recipe files must be inside the catalog and readable). Before the local catalog is replaced, the difference is shown (new / changed / removed, and `güncelleme var` for an update). `--dry-run` changes nothing. The previous `index.json` is kept as `index.json.prev`, and changed package files are kept under `.alp-catalog-prev/`. **The catalog is not signed.** Trust comes from https plus the optional `--sha256`. Package archives are still checked with sha256 at install time.
- **Build cleanup.** After a successful recipe install, `build-*`/`destdir-*` (and their upgrade equivalents) are deleted. After a failed build they stay for debugging. `--keep-build` keeps all of them.

asistan 014 verification: Windows **153 passed / 12 skipped**; Linux (Ubuntu 24.04, Python 3.12.3, user `sa`, real permissions) **165 passed / 0 skipped**; 12 of 12 mutations were caught by the tests; a real `kill -9` attempt (see handoff 014).

## M04: safely adopting installed LFS packages (2026-09-24)

`alp adopt-base --manifest FILE --name NAME --version VERSION --source-sha256 HEX [--manifest-sha256 HEX]` records ownership of files that were already installed, after comparing them with the live root. The caller must check the expected checksums of the source archive and the manifest. The manifest JSON alone does not prove the source identity. The command checks file or symlink type, content or target, size, mode and uid/gid; it refuses conflicting paths and does not take ownership of shared directories. It creates a record with `method: "lfs-base"` and `protected: true`. alp keeps these records from remove, unprotect, upgrade and reinstall. `--dry-run` shows the proposed record without writing it.

The feature was added in commit `7b2c657`, after asistan 014. `alp.py` SHA-256 `0475ea324b16895d3acbf3aebdab01d5d3a36900570f2562ca514008b11c2fc3`. Full Windows test suite: **170 passed, 13 skipped**; `py_compile`, `check_docs.py` (0 findings) and `git diff --check` passed. The adoption was not tested on the Linux builder. The feature was not installed into `/mnt/lfs`, and the live package DB is still empty. Limits and the checks still needed are in [`m02-alp-base-adoption-2026-09-24.md`](../../../verification/m02-alp-base-adoption-2026-09-24.md).

## `--relocate` and `@PREFIX@` (2026-09-26)

Recipes write the install prefix as `@PREFIX@` instead of a fixed `/usr`. By default alp sets it to `/usr`, so the alpbahOS behaviour does not change. With `--relocate`, and when `--root` is not `/`, the prefix becomes `<root>/usr`: the package is built for the root directory itself, and the `DESTDIR/<root>` subtree of the `make install DESTDIR=...` output is copied into the root. A package that installs files outside the root (for example, a fixed `/etc`) is refused. The purpose is that programs installed under another distribution (for example, `~/.local/share/alp/root` on Fedora) can find their data files at run time. Without `--relocate`, figlet gave the error `Unable to open font file`.

Verification (Fedora 44, Python 3.14.7, GCC 16.2.1, glibc 2.43): `python3 -m pytest tests/ -q` → 189 passed, 0 skipped (new `tests/test_relocate.py`: 6 tests, 3 of them with a real `make`). Installing the `alpbahOS-alp` catalog with `--relocate`: figlet, units, jq and bc installed and ran. socat did not compile because glibc 2.43 changed `strchr` to const. tmux (`libevent`) and zsh/htop/less (`ncursesw`) stopped because development libraries were missing on the host. This change was not run on the alpbahOS rootfs.

## Turkish help screen (2026-09-26)

`alp`, `alp help` and `alp --help` show a grouped help screen with examples, in Turkish (coloured in a terminal; `NO_COLOR` is respected). `alp <command> --help` is also in Turkish. A mistyped command gets a suggestion (`alp instal` → `alp install`). Global options (`--dry-run`, `--json`, `--root`, …) can now be written before or after the command. Developer options: `alp help gelistirici`. Test: `tests/test_cli_help.py`; the full package had 198 passing tests on Fedora 44.

## Catalog growth: searchable descriptions, `@DESTDIR@`, Flatpak version (2026-09-26)

- Catalog entries accept an optional `description`. `alp search` now searches names and descriptions, and shows the result as an aligned table with the description. Turkish dotted `İ` matches correctly (`DÜZENLEYİCİ` matches `düzenleyici`). `--json` output adds `description` when it exists (an extra field; the contract does not break).
- Recipe placeholder `@DESTDIR@`: if `make_install` contains it, alp does not append `DESTDIR=` at the end; it replaces the placeholder with the staging directory. Used for Makefiles that use DESTDIR in a non-standard way (for example, tree: `DESTDIR=@DESTDIR@@PREFIX@/bin`).
- A Flatpak entry without `version` no longer shows a version in the plan (it does not print "unknown"). After installation, the real version is read with `flatpak list --columns=application,version` and saved.

Verification: Fedora 44, 209 tests passed. Real Flatpak install and remove: `alp install -y flatseal` → `flatseal (flatpak) -> 2.4.1 kuruldu` (installed), then `alp remove -y flatseal` removed it cleanly.
