# `alp` — configuration protection (`upgrade` + `.alpnew`/`.alpsave`) design

Status: **implemented and tested (2026-09-21).** `_config_aware_merge()`, `upgrade_recipe()`/`upgrade_core()`, `cmd_upgrade`, and the `.alpsave` branch of `remove_package` were added to `alp.py`. 12 new tests (`tests/test_alp.py`) confirmed the behaviour: an unchanged config is silently upgraded; a changed config produces `.alpnew` and leaves the user's file alone; `remove` keeps a changed config as `.alpsave`; dropped files are cleaned up. **Still not tested:** a full upgrade on a real Linux host with the `recipe` method (which needs `configure/make`). Only the `core` method was verified end to end (local-file based), because the host had no toolchain. The current design goal (D126, v2): upgrades are started by the user; alp does not send update notifications.

This design closes the largest gap in the proposal's comparison table (§6): *"Configuration protection: none — the prototype does not handle upgrades at all, only install/remove."* The design below is the `alp` equivalent of the `.pacnew`/`.pacsave` mechanism used by Arch-family package managers. Users are already familiar with that pattern, and it is a proven UX. Reusing a known, well-understood pattern instead of inventing a new mechanism fits the CLAUDE.md principle "customise existing components, do not invent" (here the "component" is a UX pattern). The text below is kept as the original design; the implemented code followed it exactly.

## 1. Scope

Until now, `alp` had **no `upgrade` command**. The `build_parser()` in `alp.py` only had the `search/info/install/remove/list/update` subcommands, and `update` was a no-op that only re-read `index.json`. This design proposes two new parts:

1. An optional `config_files` field in the manifest schema (to mark which installed files count as "configuration").
2. A new `alp upgrade <name>` command and its `.alpnew`/`.alpsave` behaviour.

## 2. Manifest schema extension

An optional field is added to recipe/core entries:

```json
{
  "name": "htop",
  "version": "3.3.1",
  "...": "...",
  "config_files": ["/etc/htoprc.default"]
}
```

`config_files` is a subset of `files[]`. During installation, it is intersected with the full path list produced by `_merge_staged()`, which is the only merge path (since 2026-09-23, install, upgrade and `--reinstall` for both recipe and core go through it; see `docs/handoffs/claude/011-alp-logic-review-fixes.md`). This matches Debian's `conffiles` list or the `backup` array in the package metadata (`.PKGINFO`) used by Arch-family tools. It is not a new concept; it adds a well-known pattern to the `alp` schema.

## 3. `db.json` schema extension

Each package record gets a hash table, but only for the paths in `config_files` (not for every file, to keep the database small):

```json
{
  "name": "htop",
  "version": "3.3.0",
  "...": "...",
  "config_hashes": {
    "/etc/htoprc.default": "<sha256 at install time>"
  }
}
```

It is persisted through the same atomic write (`tmp` + `replace`) that `save_db` already uses, so no new file or lock mechanism is needed.

## 4. `alp upgrade <name>` flow

```
1. Read the old record from db.json (if none: "not installed", stop).
2. Resolve the new version's recipe/core entry from index.json.
3. Download the new version and check its checksum (the existing fetch() is reused as-is).
4. Extract the new version into a temporary DESTDIR/extract area (the same
   as the existing install_recipe/install_core steps; instead of duplicating
   code, these functions can be reused with a "target root" parameter).
5. Compare the old files[] with the new file list:
   a. Files only in the old list, not config -> deleted (a removed file;
      same as the existing remove_package logic, including directory cleanup).
   b. Files only in the new list -> copied normally.
   c. Files in both lists, not config -> overwritten.
   d. For every path in config_files, the decision tree in section 5 applies.
6. Update db.json with the new record (new files[], new config_hashes).
7. PRINT the full list of new .alpnew files to the user (never dropped silently).
   This is the equivalent of the "Warning: .pacnew files" output of Arch-family tools.
```

Under D126, this command runs only when the user starts it. alp does not check for or announce updates on its own.

## 5. Decision tree: when a config file produces `.alpnew`

For each `config_files` path:

```
current_hash = sha256(file on disk)   # if the file is missing: "deleted" state, handled separately
recorded_hash = config_hashes[path] in db.json   # hash at install / last upgrade
new_hash = sha256(file in the new version)

if current_hash == recorded_hash:
    # the user never touched it -> safe to overwrite
    replace the file on disk with the new content
    config_hashes[path] = new_hash
otherwise (current_hash != recorded_hash):
    # the user changed it -> do NOT touch the user's file
    write the new content as "<path>.alpnew"
    config_hashes[path] = recorded_hash   # unchanged; the user's file
                                          # is still considered "modified"
    tell the user: "<path>.alpnew created, merge by hand"
```

This is the same decision tree as the `.pacnew` mechanism of Arch-family tools. It is intentionally not reinvented: users already know this behaviour.

## 6. Interaction with `alp remove` (`.alpsave`)

The existing `remove_package` (in `alp.py`) does not know about config differences. It deletes every path in `files[]` unconditionally. With this design:

```
when remove_package runs, for every path in config_files:
    current_hash = sha256(file on disk)
    recorded_hash = config_hashes[path]
    if current_hash == recorded_hash:
        delete normally (current behaviour)
    else:
        copy to "<path>.alpsave", then delete
        report "saved as <path>.alpsave"
```

The rest of `remove_package` (file and directory cleanup, reverse-order deletion; see the directory fix in `003-alp-review-fixes.md`) **stays unchanged**. Only the config files get this extra branch.

## 7. Test plan (follows the existing `tests/test_alp.py` pattern)

Test cases defined in the original design (the 12 tests added on 2026-09-21 cover these behaviours, as described in the status above):

1. `test_upgrade_overwrites_untouched_config` — upgrade after install, config file not touched; new content is written directly, no `.alpnew` is created.
2. `test_upgrade_preserves_modified_config_as_alpnew` — config file is edited by hand; after the upgrade, the original (user-modified) file is unchanged, and `<path>.alpnew` is created with the new content.
3. `test_remove_untouched_config_deletes_normally`.
4. `test_remove_modified_config_creates_alpsave`.
5. `test_upgrade_removes_files_dropped_in_new_version` (non-config files that exist in the old version but not in the new one are removed; consistent with the existing directory-cleanup logic).

## 8. Things this design deliberately does not handle

- **Three-way merge** — the Arch-family tools do not do this either; the user merges the `.pacnew` file by hand. `alp` accepts the same limit and does not promise more.
- **Flatpak method** — no config concept; flatpak manages its own data/config directories (`~/.var/app/`). Out of scope for this design (the proposal §6 already marks it "intentionally not in flatpak").
- **Dependency and ABI breakage** (for example, a library becoming incompatible when its version jumps) — the same as the proposal §6 note that "version transitions are not handled at all". This design does not solve it; it only solves the config file problem.

## 9. Acceptance criteria

This design counts as "done" when it is in code, which it now is: the tests in §7 (written in this round as 12 `pytest` tests) **pass** ✅, AND an upgrade cycle of at least one real package on a real Linux host (with both a changed and an unchanged config file, using real `configure/make`) is checked by hand ❌ — **not done yet**. The host has no toolchain; the BLFS build environment is needed.

## 10. Rollback and `alp recover` (2026-09-24)

An upgrade or remove that is interrupted no longer leaves the system partly changed. Each package operation keeps a journal (`var/lib/alp/rollback/`): record and backup before writing, reverse steps on error, and a `commit` marker after the database write. A journal left by a process that died with `kill -9` is rolled back with `alp recover`. Details, limits (no fsync; a small window before the commit) and verification: `../014-alp-m02-rollback-update-protect.md`. The `.alpnew`/`.alpsave` rules above are unchanged. A file moved to `.alpsave` is also written to the journal and can be rolled back.
