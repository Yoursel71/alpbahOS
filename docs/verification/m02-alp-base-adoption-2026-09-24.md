# Alp base package adoption — 24 September 2026

## Change and purpose

Claude handoff 014's reviewed Alp source was verified first: the `alp.py`
blob at commit `15de293` had SHA-256
`3c72bbf27ee601311c1b84c8968c45ebafb951841229b08b01463ee363fe1c89`.
Codex then added `adopt-base` in commit `7b2c657`; the integrated prototype
`docs/handoffs/claude/alp-prototype/alp.py` now has SHA-256
`0475ea324b16895d3acbf3aebdab01d5d3a36900570f2562ca514008b11c2fc3`.

`adopt-base` imports an already-installed LFS package record only after the
caller independently verifies the source archive and manifest. It validates
manifest identity/schema, source and manifest SHA-256 values, normalized paths,
live file/symlink type, content, size, mode, uid/gid, and package path conflicts.
Shared directories are checked but not owned. The resulting `lfs-base` record
is protected; removal, unprotection, upgrade, and reinstall are refused.
`--dry-run` prints the candidate record without changing the package DB.

`alp check` or `alp update` can still display a stale “update available” notice
if the catalog contains a package with the same name; the upgrade itself is
blocked. This is a UI/reporting caveat, not an ownership mutation path.

The manifest itself does not authenticate its source. The caller must check the
official source checksum and expected manifest hash independently before
adoption. The command does not claim source provenance from Unix file ownership
or a manifest alone.

## Verification

- Windows Python 3.14: `python -m pytest docs/handoffs/claude/alp-prototype/tests -q` — **170 passed, 13 skipped**. The skipped cases require POSIX permissions/symlink behavior unavailable in this Windows account.
- `python -m py_compile docs/handoffs/claude/alp-prototype/alp.py` passed.
- `python docs/handoffs/claude/tools/check_docs.py` — **0 findings**.
- `git diff --check` passed.
- Tests cover positive adoption, no-directory ownership, repeated adoption, dry-run immutability, malformed schema/identity/source/hash/path, conflicting claims, content/type/mode/uid mismatch, and removal/upgrade/reinstall protection.

## Current deployment boundary

This is repo code only. It has **not** been installed into Builder `/mnt/lfs`,
and the live `/mnt/lfs/var/lib/alp/db.json` remains schema 1 with an empty
`packages` map. Before importing records, test this exact integrated version on
Builder Linux against isolated fixtures and a real read-only `--dry-run` for a
manifest with an exact current-rootfs preflight. Only then adopt matching
packages one at a time. Current M04 stage-only builds still pin the old rootfs
Alp SHA-256 `7b2998a5f76fbae2702c07b5325cd9679a29c11a5a8617eca9bd01a0d4aef132`;
update those guards only after a deliberate Builder integration.
