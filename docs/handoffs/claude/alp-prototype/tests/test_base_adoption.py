"""Focused tests for adopting already-installed LFS package files."""

from __future__ import annotations

import argparse
import hashlib
import json
import stat
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


SOURCE_SHA = "a" * 64


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    root = tmp_path / "root"
    (root / "usr/bin").mkdir(parents=True)
    (root / "usr/bin/tool").write_bytes(b"existing LFS tool\n")
    (root / "usr/bin/tool").chmod(0o755)
    return alp.Paths.resolve(str(root))


def _manifest(paths: alp.Paths, tmp_path: Path, *, entries=None, name="tool", version="1.0") -> Path:
    tool_stat = (paths.root / "usr/bin/tool").lstat()
    entries = entries or [
        {"path": "/usr", "type": "directory", "mode": 0o755, "uid": tool_stat.st_uid, "gid": tool_stat.st_gid},
        {"path": "/usr/bin", "type": "directory", "mode": 0o755, "uid": tool_stat.st_uid, "gid": tool_stat.st_gid},
        {"path": "/usr/bin/tool", "type": "file", "mode": stat.S_IMODE((paths.root / "usr/bin/tool").stat().st_mode), "size": 18,
         "sha256": hashlib.sha256(b"existing LFS tool\n").hexdigest(), "uid": tool_stat.st_uid, "gid": tool_stat.st_gid},
    ]
    data = {
        "schema": alp.BASE_MANIFEST_SCHEMA,
        "captured_at": "2026-09-24T00:00:00Z",
        "package": {"name": name, "version": version,
                    "source": {"url": "https://example.invalid/tool-1.0.tar.xz", "sha256": SOURCE_SHA}},
        "entries": entries,
    }
    path = tmp_path / "manifest.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def _args(manifest: Path, **overrides) -> argparse.Namespace:
    values = {"manifest": str(manifest), "name": "tool", "version": "1.0",
              "source_sha256": SOURCE_SHA, "manifest_sha256": None}
    values.update(overrides)
    return argparse.Namespace(**values)


def _db_bytes(paths: alp.Paths) -> bytes:
    paths.ensure()
    if not paths.db_file.exists():
        paths.db_file.write_text(json.dumps({"schema_version": 1, "updated_at": "before", "packages": {"sentinel": {"version": "1"}}}), encoding="utf-8")
    return paths.db_file.read_bytes()


def test_adopt_records_only_live_files_and_symlinks_and_is_idempotent(paths, tmp_path, capsys):
    manifest = _manifest(paths, tmp_path)
    assert alp.cmd_adopt_base(_args(manifest), paths) == 0
    record = alp.load_db(paths)["packages"]["tool"]
    assert record["method"] == "lfs-base"
    assert record["protected"] is True
    assert record["files"] == ["usr/bin/tool"]
    assert record["symlinks"] == []
    assert record["ownership"]["manifest_sha256"] == alp.sha256_of(manifest)
    assert "usr" not in record["files"] + record["symlinks"]
    db_before = paths.db_file.read_bytes()
    assert alp.cmd_adopt_base(_args(manifest), paths) == 0
    assert paths.db_file.read_bytes() == db_before
    capsys.readouterr()


def test_adopt_dry_run_reports_record_without_changing_database(paths, tmp_path, capsys):
    manifest = _manifest(paths, tmp_path)
    before = _db_bytes(paths)
    assert alp.cmd_adopt_base(_args(manifest, dry_run=True), paths) == 0
    output = capsys.readouterr().out
    assert "[dry-run]" in output
    assert '"method": "lfs-base"' in output
    assert '"protected": true' in output
    assert paths.db_file.read_bytes() == before
    assert "tool" not in alp.load_db(paths)["packages"]


@pytest.mark.parametrize("failure", ["changed-file", "duplicate-claim", "traversal", "malformed-identity", "bad-schema", "bad-source-sha", "manifest-hash", "mode-mismatch", "owner-mismatch", "type-mismatch"])
def test_adopt_failure_does_not_change_database(paths, tmp_path, failure):
    manifest = _manifest(paths, tmp_path)
    if failure == "changed-file":
        (paths.root / "usr/bin/tool").write_bytes(b"changed content\n")
    elif failure == "duplicate-claim":
        db = {"schema_version": 1, "updated_at": "before", "packages": {"other": {"files": ["usr/bin/tool"], "symlinks": []}}}
        paths.ensure()
        paths.db_file.write_text(json.dumps(db), encoding="utf-8")
    elif failure == "traversal":
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["entries"][0]["path"] = "/usr/../etc/passwd"
        manifest.write_text(json.dumps(data), encoding="utf-8")
    elif failure == "malformed-identity":
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["package"]["name"] = "different"
        manifest.write_text(json.dumps(data), encoding="utf-8")
    elif failure == "bad-schema":
        data = json.loads(manifest.read_text(encoding="utf-8"))
        data["schema"] = "alpbahOS.package-files/v99"
        manifest.write_text(json.dumps(data), encoding="utf-8")
    elif failure in ("mode-mismatch", "owner-mismatch", "type-mismatch"):
        data = json.loads(manifest.read_text(encoding="utf-8"))
        file_entry = next(entry for entry in data["entries"] if entry["path"] == "/usr/bin/tool")
        if failure == "mode-mismatch":
            file_entry["mode"] = file_entry["mode"] ^ 0o100
        elif failure == "owner-mismatch":
            file_entry["uid"] += 1
        else:
            file_entry["type"] = "symlink"
            file_entry["target"] = "elsewhere"
        manifest.write_text(json.dumps(data), encoding="utf-8")
    before = _db_bytes(paths)
    args = _args(manifest)
    if failure == "bad-source-sha":
        args.source_sha256 = "b" * 64
    if failure == "manifest-hash":
        args.manifest_sha256 = "0" * 64
    with pytest.raises(alp.AlpError):
        alp.cmd_adopt_base(args, paths)
    assert paths.db_file.read_bytes() == before


def test_adopt_rejects_duplicate_manifest_paths(paths, tmp_path):
    tool_stat = (paths.root / "usr/bin/tool").lstat()
    entries = [
        {"path": "/usr/bin/tool", "type": "file", "mode": stat.S_IMODE(tool_stat.st_mode), "size": 18,
         "sha256": hashlib.sha256(b"existing LFS tool\n").hexdigest(), "uid": tool_stat.st_uid, "gid": tool_stat.st_gid},
        {"path": "/usr/bin/tool", "type": "file", "mode": stat.S_IMODE(tool_stat.st_mode), "size": 18,
         "sha256": hashlib.sha256(b"existing LFS tool\n").hexdigest(), "uid": tool_stat.st_uid, "gid": tool_stat.st_gid},
    ]
    manifest = _manifest(paths, tmp_path, entries=entries)
    with pytest.raises(alp.AlpError, match="birden çok"):
        alp.cmd_adopt_base(_args(manifest), paths)
    assert not paths.db_file.exists()


def test_adopt_records_only_a_live_matching_symlink(paths, tmp_path):
    link = paths.root / "usr/bin/tool-link"
    try:
        link.symlink_to("tool")
    except (OSError, NotImplementedError):
        pytest.skip("this Windows account cannot create symlinks")
    link_stat = link.lstat()
    entries = [{"path": "/usr/bin/tool-link", "type": "symlink", "mode": stat.S_IMODE(link_stat.st_mode),
                "target": "tool", "uid": link_stat.st_uid, "gid": link_stat.st_gid}]
    manifest = _manifest(paths, tmp_path, entries=entries)
    alp.cmd_adopt_base(_args(manifest), paths)
    record = alp.load_db(paths)["packages"]["tool"]
    assert record["files"] == []
    assert record["symlinks"] == ["usr/bin/tool-link"]


def test_adopted_base_package_cannot_be_upgraded(paths, tmp_path):
    manifest = _manifest(paths, tmp_path)
    alp.cmd_adopt_base(_args(manifest), paths)
    with pytest.raises(alp.AlpError, match="LFS taban paketi"):
        alp.cmd_upgrade(argparse.Namespace(name="tool", dry_run=False, yes=True), paths,
                        {"entries": {"tool": {"method": "core", "version": "2.0"}}}, tmp_path)


def test_adopted_base_package_cannot_be_reinstalled_as_flatpak(paths, tmp_path):
    manifest = _manifest(paths, tmp_path)
    alp.cmd_adopt_base(_args(manifest), paths)
    db_before = paths.db_file.read_bytes()
    args = argparse.Namespace(name="tool", dry_run=False, reinstall=True, yes=True)
    index = {"entries": {"tool": {"method": "flatpak", "version": "2.0",
                                    "flatpak_ref": "example.tool", "remote": "flathub"}}}
    with pytest.raises(alp.AlpError, match="catalog install/reinstall/upgrade"):
        alp.cmd_install(args, paths, index, tmp_path)
    assert paths.db_file.read_bytes() == db_before
    assert (paths.root / "usr/bin/tool").is_file()


def test_adopted_base_package_cannot_be_unprotected_or_removed(paths, tmp_path):
    manifest = _manifest(paths, tmp_path)
    alp.cmd_adopt_base(_args(manifest), paths)
    with pytest.raises(alp.AlpError, match="kalıcı olarak korumalı"):
        alp.cmd_protect(argparse.Namespace(name="tool", dry_run=False), paths, protect=False)
    with pytest.raises(alp.AlpError, match="korumalı"):
        alp.cmd_remove(argparse.Namespace(name="tool", dry_run=False, cascade=False, yes=True), paths)
    db = alp.load_db(paths)
    with pytest.raises(alp.AlpError, match="doğrudan kaldırılması kapalı"):
        alp.remove_package(paths, db, "tool", dry_run=False)
    assert (paths.root / "usr/bin/tool").is_file()
    assert "tool" in alp.load_db(paths)["packages"]


def test_parser_adopt_base_does_not_require_catalog():
    args = alp.build_parser().parse_args([
        "--dry-run", "adopt-base", "--manifest", "manifest.json", "--name", "tool", "--version", "1.0",
        "--source-sha256", SOURCE_SHA,
    ])
    assert args.command == "adopt-base"
    assert args.index is None
    assert args.dry_run is True
