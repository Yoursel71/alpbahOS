# `alp` — PackageKit/Discover integration design

Status: **partly implemented (2026-09-21).** The `--json` flag and the `alp_*` wrapper functions in `alp_packagekit_backend.py` were written and **really tested** (`tests/test_packagekit_backend.py`, against `alp.py` through a subprocess, no mocks). The `AlpPackageKitBackend` class itself (the part that imports `packagekit.backend`) **has still never been run or imported**: the packagekit module was not available on the Windows host (historical). Details: the module docstring of `alp_packagekit_backend.py`.

**v2 decision (D124, 2026-11-06):** the GUI store is **KDE Discover through an alp PackageKit backend**. An earlier path through another package manager's library was dropped (v1 D31). Discover is the store UI; `alp` remains the only engine and database (D122). Two untested drafts from 2026-09-30 exist in `scripts/legacy/wip-2026-09-30/scripts/packagekit/`:

- `alpBackend.py` — a Python backend that imports `packagekit.backend` and reads the catalog and runs `alp` operations.
- `pk-backend-alp.c` — a C backend that uses PackageKit's spawn helper to run `alp`.

Neither draft has been proven to work as a PackageKit backend. The docs do not record which one will be the D124 path; that choice is open. The original 2026-09-30 candidate run is recorded in [docs/MASTER_PLAN.md](../../../../MASTER_PLAN.md) §5.2 and is **not a pass**.

The original design text below (§1–7) is still the valid contract. Its §2 and §3 wrapper part now exists as code. Everything else (the real PackageKit daemon test) is still not done.

## 1. Why this approach

The live plan (MASTER_PLAN §5, v1 §5.3 for the original rule) already defines the contract: *"The CLI and the store use the same engine, database and lock."* `alp` already provides this with `db.json` + `DbLock` (D122). What is missing is the layer that connects Discover's protocol (the `org.freedesktop.PackageKit` D-Bus interface) to `alp`.

Two realistic options:

| Option | Pros | Cons |
|---|---|---|
| **A. Python PackageKit backend** (`packagekit.backend` module, wraps the CLI) | Little code; `alp`'s own process and lock model is kept; no C needed | Python backends are less common and less maintained in the PackageKit ecosystem; performance depends on the CLI spawn cost |
| **B. C backend (modelled on an existing native C backend)** | The native path PackageKit expects; most mature | Requires moving or bridging `alp`'s Python logic to C — a large extra job, and it conflicts with `alp`'s "simple, stdlib-only" design goal |

**Recommendation: A.** `alp` was already designed for simplicity and speed (the reason for D31 in v1). The CLI spawn cost is acceptable for rare operations like install and remove. B would give up the whole philosophy (simplicity). The 2026-09-30 drafts include both A and B; the choice between them is still open (see the status section at the top).

## 2. Required prerequisite: a structured output mode for `alp`

**Originally, `alp search`/`alp list` printed human-readable plain text.** A backend parsing that text would be fragile (the same idea as the proposal §7 principle "spelling help never silently rewrites arguments or file names": a contract format instead of fragile text parsing). That is why the `--json` flag had to be added to `alp` before the backend was written:

```
alp --json search <term>    -> JSON array: [{"name":..., "method":...}, ...]
alp --json info <name>      -> already prints JSON (cmd_info), even without --json
alp --json list             -> JSON array: [{"name":..., "version":..., "method":...}, ...]
```

This is a small, isolated change to `alp.py` (branching the output format of `cmd_search`/`cmd_list`). This document only records it as a prerequisite; it does not write the code.

## 3. PackageKit method mapping

| PackageKit method | `alp` equivalent | Note |
|---|---|---|
| `SearchNames` / `SearchDetails` | `alp --json search <term>` | Direct match |
| `Resolve` | `alp --json info <name>` | Installed / not-installed status already in `cmd_info` |
| `GetDetails` | `alp --json info <name>` | `source` and `version` fields already exist |
| `GetFiles` | `files[]` in `db.json` | Already included in `alp --json info` output |
| `InstallPackages` | `alp install --yes <name>`; before approval, `alp --json --dry-run install <name>` | Progress: `--progress-fd`, see §4 |
| `RemovePackages` | `alp remove <name>` | Same |
| `GetUpdates` / `UpdatePackages` | `alp --json --dry-run upgrade` (`alp_updates`) / `alp upgrade --yes <name>` | 2026-09-28: `alp upgrade` is real; `alp_updates` reads the plan, including dependency upgrades; held-back packages are in the `kept_back` field. Under D126 updates start only when the user starts them. |
| `GetRepoList` | The one entry of `demo/index.json` (on a real system, the `alpbahOS-alp` repository) | `alp` has no multi-repo concept. MASTER_PLAN's rule "if there are several sources, they must be visible" is met automatically with one repository. Flathub (D125) is a separate flatpak channel and is not part of this list. |

## 4. Progress reporting (missing; design needed)

PackageKit expects `Percentage`/`Status` signals during `InstallPackages`, and Discover shows them in a progress bar. `alp` was a single one-shot command with no progress stream.

Proposed protocol: `alp install <name> --progress-fd <N>` writes one JSON line per event to file descriptor `N` (for example `{"phase":"download","pct":42}`, `{"phase":"build"}`, `{"phase":"done"}`). The backend reads this FD and turns it into PackageKit signals. This keeps `alp`'s stdout (the messages for humans) free of machine output. It is the standard Unix "extra machine-readable channel" pattern.

**2026-09-28: implemented and tested** (`tests/test_store_contract.py`). Events are one JSON object per line: `plan` (steps); for each package `step` `start`/`done` (`index`, `total`, `percentage`); the `phase` event (`download`, `build` with `step` = configure/make/make_install, `merge`); on error `error` (`message`, `completed`); and `done` at the end. Removal sends the same `step`/`done` events. **2026-11-12:** a transaction whose packages name catalogue triggers (`ldconfig`, `depmod`) sends one `trigger` event per command (`name`, `command`, `returncode`) after the last `step` and before `done`. If the reader closes, the operation is not broken; the events are simply dropped. Writing the PackageKit class that turns this channel into `Percentage`/`Status` signals is not done; it needs a test on a real daemon.

## 5. Authorisation (polkit)

MASTER_PLAN (v1 §5.3, live §5.1): *"Root access is never given to the whole store. Install and remove go through a separate authorised action."* AGENT.md: *"Limit root operations to the steps that need them; do not run the whole flow as root."*

Design: a PolicyKit action file named `org.alpbahos.alp.pkgkit.policy`:

```xml
<action id="org.alpbahos.alp.pkgkit.install-remove">
  <description>Install/remove packages with alp</description>
  <defaults>
    <allow_any>auth_admin</allow_any>
    <allow_inactive>auth_admin</allow_inactive>
    <allow_active>auth_admin_keep</allow_active>
  </defaults>
</action>
```

`search`/`list`/`info`/`get-files` **do not ask for authorisation** (they are read-only, so everyone must be able to read `db.json` even with `--root /`; file permissions must be `0644`, and `alp.lock`/write operations `0600` and root-owned). Only `install`/`remove` (and the future `upgrade`) require `auth_admin`. This matches the only step of `install_recipe` that needs root (copying into `/` in `_merge_staged`). AGENT.md: "only the file copy / DESTDIR merge step needs write access to `/`; the whole `alp` process does not have to run as root."

## 6. Interaction with the lock

When the backend spawns `alp install`, `alp`'s own `DbLock` already gives the single-writer guarantee. If someone runs `alp install` by hand while Discover also starts an install, the second call returns `AlpError: "Veritabanı kilitli..."` (the current, tested behaviour; see `tests/test_alp.py::test_db_lock_blocks_second_writer`). The backend should catch that exact error text (`alp: hata: ... kilitli ...` on stderr) and return the PackageKit code `PK_ERROR_ENUM_LOCK_REQUIRED`, so Discover shows "another operation is running" and not the raw error text.

## 7. Acceptance criteria (per MASTER_PLAN §5 and the M02 criterion)

This design counts as "accepted" only after the following (the same as acceptance criterion PKG-02 in the proposal §6):

1. The `alp --json` output mode is implemented and tested (§2 of this design).
2. A Python PackageKit backend is written, loaded into a real PackageKit daemon on Linux (a BLFS environment), and tested end to end with `pkcon` / Discover.
3. The progress protocol in §4 is implemented.
4. The polkit action file in §5 is tested on a real polkit installation.
5. `GetUpdates`/`UpdatePackages` can be added only after the `alp upgrade` design in [config-protection.md](config-protection.md) is in code (it now is; see that file's status).

**2026-09-28 (PKG-02 contract):** item 3's `alp` side is done: the `--progress-fd` event channel and the machine-readable plan before approval (`--json --dry-run install|upgrade|remove`: steps, `problems`, `download_size` taken from the catalog `size` field; `null` when the size is unknown, not estimated). The backend wrappers `alp_plan` and `alp_updates` were added and tested. `AlpPackageKitBackend.get_updates` was written but has not been tried on a real PackageKit. Items 2 and 4 (daemon and polkit tests) are still open.

**2026-09-21 status:** item 1 (`--json`) and the first half of item 2 (the `alp_*` wrappers) are complete and tested. Items 2, 3 and 4 were not fully done: `AlpPackageKitBackend` was written but never loaded into a real PackageKit daemon. The M02 criterion for the "integration test" part is **still not met**; a real BLFS/PackageKit environment is needed.
