# ShellCheck baseline, 2026-11-10

Environment: Fedora host, ShellCheck 0.11.0 from `pip install shellcheck-py` in a throwaway venv.
This is a local measurement. The first CI run (`.github/workflows/repo-tests.yml`) is not run yet.

Scope: tracked `*.sh` files and tracked files with a `sh`/`bash` shebang, except
`scripts/legacy/`, `tests/legacy/`, `docs/archive/`. File list: `scripts/ci/list-shell-files.sh`.

| Item | Count |
|------|-------|
| Files checked | 790 |
| Errors (`-S error`) | 0 |
| Warnings (`-S warning`, errors excluded) | 1166 |

Commands (run from the repo root):

```text
scripts/ci/list-shell-files.sh > files.txt
xargs -a files.txt -d '\n' shellcheck -S error -e SC2148
xargs -a files.txt -d '\n' shellcheck -S warning -e SC2148 -f gcc | grep -c 'warning:'
```

Rule SC2148 (missing shebang) is switched off: 357 files under
`scripts/lfs-blfs/build-cmds/packages/` and a few `scripts/rebuild/r4/deltas/` files are fragments
that are sourced or pasted, not executed.

Errors found before the baseline and how they were handled:

| File | Error | Handling |
|------|-------|----------|
| `scripts/lfs-blfs/calamares/runner/m11-run.sh` lines 309, 333 | SC1087 `$UUID[[:space:]]` | Fixed: `${UUID}[` and `${ESP_UUID}[` (same meaning) |
| `scripts/lfs-blfs/build-cmds/packages/064-NetworkManager-1.54.0.sh` line 86 | SC1073 unquoted `<username>` placeholder | Excluded in `list-shell-files.sh` |
| `scripts/lfs-blfs/build-cmds/packages/184-cups-2.4.12.sh` line 21 | SC1073 `<username>` placeholder | Excluded |
| `scripts/lfs-blfs/build-cmds/packages/200-sddm-0.21.0.sh` line 116 | SC1073 `<theme path>` placeholder | Excluded |
| `scripts/lfs-blfs/build_image7.sh` line 53 | SC2225 `cp` without destination (stray placeholder line) | Excluded |

The four excluded files need a real edit by their owner, then the exclusion can be removed.
