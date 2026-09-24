# M04 repository recipe-script identity inventory — 24 September 2026

The machine-readable snapshot is
[`m04-recipe-identity-inventory-2026-09-24.json`](m04-recipe-identity-inventory-2026-09-24.json).
It follows the pinned official Chapter 8 order of 79 packages and records
dedicated `scripts/build-m04-<package>-stage.sh` files only.

## Result

- 79 official package rows, in pinned order.
- 29 packages have a dedicated M04 stage script; the JSON records the exact
  relative path and SHA-256 of each scanned file.
- 50 packages have no file matching that dedicated naming rule. This does not
  assert that recipe text is absent from the repository or official LFS book.
- The JSON pins its source package-list path/hash and repository ref/commit.
  It was generated from the current worktree and records its dirty-at-scan
  state; the script hashes are file-content hashes.

Generate a fresh snapshot and exercise the scope checks with:

```text
python scripts/audit_m04_recipe_identities.py --repo-root . --output docs/verification/m04-recipe-identity-inventory-2026-09-24.json
python -m pytest -q tests/test_m04_recipe_identity_inventory.py
```

## Evidence boundary

This is a repository inventory, **not historical Builder provenance**. It does
not prove these scripts were the bytes used for earlier builds or installs,
authenticate source archives or generated patches, record a final-rootfs
install event, or assign ownership. The current stage scripts use `DESTDIR`;
they cannot be treated as observed final-rootfs writes. M04 remains open at
0/79 observed install events, and the Alp package database remains outside this
inventory.

## Validation

- `python -m pytest -q tests/test_m04_recipe_identity_inventory.py` — **3
  passed**.
- `python -m py_compile scripts/audit_m04_recipe_identities.py tests/test_m04_recipe_identity_inventory.py`
  — passed.
- A fresh JSON generation recomputed 29 present script hashes against the same
  worktree; all 79 ordered package rows and 50 missing-script statuses were
  included.
