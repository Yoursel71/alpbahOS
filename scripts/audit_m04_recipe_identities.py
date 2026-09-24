#!/usr/bin/env python3
"""Inventory dedicated M04 stage-script identities for the pinned LFS order.

This records current repository-file identities only. It does not establish
which recipe bytes ran on Builder or prove an install into the final rootfs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


PINNED_LIST = Path("docs/verification/manifests/lfs-base/m04-expected-chapter8-packages-12.4.json")
SCHEMA = "alpbahOS.m04-recipe-identity-inventory/v1"
CAVEAT = (
    "Repository identity inventory only: a present hash identifies the exact script bytes "
    "in the scanned worktree. It does not prove those bytes were used in any past Builder "
    "build or install, does not authenticate downloaded sources or generated patches, and "
    "does not constitute an observed final-rootfs install event or ownership evidence. "
    "Missing means no dedicated scripts/build-m04-<package>-stage.sh file was found by "
    "the exact naming rule; it does not assert that no recipe text exists elsewhere."
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _run_git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def _package_script_name(package_name: str) -> str:
    # This is a strict filename convention, not fuzzy discovery or aliasing.
    return package_name.lower().replace("::", "-")


def build_inventory(
    root: Path,
    *,
    packages_file: Path = PINNED_LIST,
    repo_commit: str,
    repo_ref: str,
    worktree_dirty: bool,
) -> dict[str, Any]:
    root = root.resolve()
    package_path = (root / packages_file).resolve()
    try:
        package_path.relative_to(root)
    except ValueError as exc:
        raise ValueError("pinned package list must be inside repository root") from exc

    pinned = json.loads(package_path.read_text(encoding="utf-8"))
    if pinned.get("schema") != "alpbahOS.m04-expected-packages/v1":
        raise ValueError("unexpected pinned package-list schema")
    packages = pinned.get("packages")
    if not isinstance(packages, list) or len(packages) != 79:
        raise ValueError("expected exactly 79 pinned LFS Chapter 8 package rows")

    rows: list[dict[str, Any]] = []
    seen_names: set[str] = set()
    for index, package in enumerate(packages, start=1):
        name = package.get("name")
        version = package.get("version")
        if not isinstance(name, str) or not name or not isinstance(version, str) or not version:
            raise ValueError(f"invalid package identity at row {index}")
        if name in seen_names:
            raise ValueError(f"duplicate package name in pinned list: {name}")
        seen_names.add(name)

        relative = Path("scripts") / f"build-m04-{_package_script_name(name)}-stage.sh"
        path = root / relative
        if path.is_symlink():
            raise ValueError(f"dedicated stage script must be a regular non-symlink file: {relative}")
        if path.exists() and not path.is_file():
            raise ValueError(f"dedicated stage script path exists but is not a regular file: {relative}")
        if path.is_file():
            rows.append({
                "index": index,
                "name": name,
                "version": version,
                "script_status": "present",
                "script": {
                    "path": relative.as_posix(),
                    "sha256": _sha256(path),
                },
            })
        else:
            rows.append({
                "index": index,
                "name": name,
                "version": version,
                "script_status": "missing",
                "script": None,
            })

    present = sum(row["script_status"] == "present" for row in rows)
    return {
        "schema": SCHEMA,
        "scope": "dedicated per-package scripts/build-m04-<package>-stage.sh files only",
        "repository": {
            "ref": repo_ref,
            "commit": repo_commit,
            "worktree_dirty_at_scan": worktree_dirty,
            "hash_basis": "current worktree file bytes",
        },
        "pinned_package_list": {
            "path": packages_file.as_posix(),
            "sha256": _sha256(package_path),
            "schema": pinned["schema"],
            "package_count": len(rows),
        },
        "coverage": {
            "present_dedicated_scripts": present,
            "missing_dedicated_scripts": len(rows) - present,
        },
        "provenance_caveat": CAVEAT,
        "packages": rows,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, help="write JSON to this path; default is stdout")
    args = parser.parse_args(argv)

    root = args.repo_root.resolve()
    try:
        commit = _run_git(root, "rev-parse", "HEAD")
        branch = _run_git(root, "branch", "--show-current") or "detached"
        dirty = bool(_run_git(root, "status", "--porcelain"))
        inventory = build_inventory(
            root,
            repo_commit=commit,
            repo_ref=branch,
            worktree_dirty=dirty,
        )
        encoded = json.dumps(inventory, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            output = args.output if args.output.is_absolute() else root / args.output
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_text(encoded, encoding="utf-8", newline="\n")
        else:
            sys.stdout.write(encoded)
    except (OSError, subprocess.CalledProcessError, ValueError, json.JSONDecodeError) as exc:
        print(f"audit-m04-recipe-identities: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
