"""PKG-02 store contract: machine-readable plan (--json --dry-run) and the
--progress-fd JSON-line event channel (design/packagekit-integration.md §4).

Same rules as the other suites: no network, real tarballs under tmp_path.
"""

from __future__ import annotations

import io
import json
import os
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def _core(tmp_path: Path, name: str, version: str = "1.0.0", depends=None, size=None) -> dict:
    archive = tmp_path / f"{name}-{version}.tar.gz"
    content = f"{name} {version}".encode()
    with tarfile.open(archive, "w:gz") as tf:
        for d in ("usr", "usr/share", f"usr/share/{name}"):
            info = tarfile.TarInfo(d)
            info.type = tarfile.DIRTYPE
            info.mode = 0o755
            tf.addfile(info)
        info = tarfile.TarInfo(f"usr/share/{name}/data")
        info.size = len(content)
        tf.addfile(info, io.BytesIO(content))
    entry = {"method": "core", "name": name, "version": version,
             "url": archive.name, "sha256": alp.sha256_of(archive)}
    if depends:
        entry["depends"] = depends
    if size is not None:
        entry["size"] = size
    return entry


def _catalog(tmp_path: Path, entries: dict) -> Path:
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"entries": entries}), encoding="utf-8")
    return index


def _run(capsys, *argv) -> tuple[int, str]:
    code = alp.main(list(argv))
    return code, capsys.readouterr().out


def test_install_plan_json_lists_dependencies_first_and_changes_nothing(tmp_path, capsys):
    root = tmp_path / "root"
    index = _catalog(tmp_path, {
        "lib": _core(tmp_path, "lib", size=100),
        "app": _core(tmp_path, "app", depends=["lib>=1.0"], size=250),
    })
    code, out = _run(capsys, "--root", str(root), "--index", str(index), "--json", "--dry-run", "install", "app")
    plan = json.loads(out)
    assert code == 0
    assert plan["command"] == "install"
    assert [(s["action"], s["name"], s["reason"]) for s in plan["steps"]] == [
        ("install", "lib", "dependency"), ("install", "app", "explicit")]
    assert plan["problems"] == []
    assert plan["download_size_total"] == 350
    assert plan["already_installed"] is False
    assert not (root / "usr/share/app").exists()
    assert alp.load_db(alp.Paths.resolve(str(root)))["packages"] == {}


def test_plan_json_size_is_null_when_catalog_does_not_say(tmp_path, capsys):
    index = _catalog(tmp_path, {"lib": _core(tmp_path, "lib", size=100), "app": _core(tmp_path, "app", depends=["lib"])})
    _, out = _run(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "--json", "--dry-run", "install", "app")
    plan = json.loads(out)
    assert [s["download_size"] for s in plan["steps"]] == [100, None]
    assert plan["download_size_total"] is None  # never a partial sum shown as the total


def test_plan_json_reports_conflict_as_problem_with_exit_1(tmp_path, capsys):
    root = tmp_path / "root"
    entries = {"lib": _core(tmp_path, "lib")}
    index = _catalog(tmp_path, entries)
    alp.main(["--root", str(root), "--index", str(index), "install", "lib", "--yes"])
    capsys.readouterr()
    entries["app"] = {**_core(tmp_path, "app"), "conflicts": ["lib"]}
    index = _catalog(tmp_path, entries)
    code, out = _run(capsys, "--root", str(root), "--index", str(index), "--json", "--dry-run", "install", "app")
    plan = json.loads(out)
    assert code == 1
    assert [s["name"] for s in plan["steps"]] == ["app"]
    assert len(plan["problems"]) == 1 and "çakışıyor" in plan["problems"][0]
    assert not (root / "usr/share/app").exists()


def test_plan_json_unsatisfiable_dependency_is_an_error_not_a_plan(tmp_path, capsys):
    root = tmp_path / "root"
    index = _catalog(tmp_path, {"lib": _core(tmp_path, "lib", "1.0.0"),
                                "app": _core(tmp_path, "app", depends=["lib>=2.0"])})
    code = alp.main(["--root", str(root), "--index", str(index), "--json", "--dry-run", "install", "app"])
    captured = capsys.readouterr()
    assert code == 1
    assert captured.out == ""
    assert "lib>=2.0" in captured.err


def test_remove_plan_json_includes_cascade_order_and_orphans(tmp_path, capsys):
    root = tmp_path / "root"
    index = _catalog(tmp_path, {"lib": _core(tmp_path, "lib"), "app": _core(tmp_path, "app", depends=["lib"])})
    alp.main(["--root", str(root), "--index", str(index), "install", "app", "--yes"])
    capsys.readouterr()
    code, out = _run(capsys, "--root", str(root), "--index", str(index), "--json", "--dry-run", "remove", "app")
    plan = json.loads(out)
    assert code == 0
    assert [s["name"] for s in plan["steps"]] == ["app"]
    assert plan["orphans_after"] == ["lib"]
    assert (root / "usr/share/app/data").is_file()


def test_progress_fd_emits_plan_steps_phases_and_done(tmp_path, capsys):
    root = tmp_path / "root"
    index = _catalog(tmp_path, {"lib": _core(tmp_path, "lib"), "app": _core(tmp_path, "app", depends=["lib"])})
    read_fd, write_fd = os.pipe()
    try:
        code = alp.main(["--root", str(root), "--index", str(index), "--progress-fd", str(write_fd), "install", "app", "--yes"])
    finally:
        os.close(write_fd)
    with os.fdopen(read_fd, "r", encoding="utf-8") as reader:
        events = [json.loads(line) for line in reader.read().splitlines()]
    capsys.readouterr()
    assert code == 0
    assert events[0]["event"] == "plan"
    assert [s["name"] for s in events[0]["steps"]] == ["lib", "app"]
    steps = [(e["name"], e["phase"], e["percentage"]) for e in events if e["event"] == "step"]
    assert steps == [("lib", "start", 0), ("lib", "done", 50), ("app", "start", 50), ("app", "done", 100)]
    phases = [(e["name"], e["phase"]) for e in events if e["event"] == "phase"]
    assert phases == [("lib", "download"), ("lib", "merge"), ("app", "download"), ("app", "merge")]
    assert events[-1] == {"event": "done", "completed": ["lib", "app"]}


def test_progress_fd_reports_error_with_completed_steps(tmp_path, capsys):
    root = tmp_path / "root"
    entries = {"lib": _core(tmp_path, "lib"), "app": _core(tmp_path, "app", depends=["lib"])}
    entries["app"]["sha256"] = "0" * 64  # checksum failure on the second step
    index = _catalog(tmp_path, entries)
    read_fd, write_fd = os.pipe()
    try:
        code = alp.main(["--root", str(root), "--index", str(index), "--progress-fd", str(write_fd), "install", "app", "--yes"])
    finally:
        os.close(write_fd)
    with os.fdopen(read_fd, "r", encoding="utf-8") as reader:
        events = [json.loads(line) for line in reader.read().splitlines()]
    capsys.readouterr()
    assert code == 1
    error = [e for e in events if e["event"] == "error"]
    assert len(error) == 1 and error[0]["name"] == "app" and error[0]["completed"] == ["lib"]
    assert "Checksum" in error[0]["message"]
    assert not any(e["event"] == "done" for e in events)


def test_progress_fd_invalid_descriptor_is_a_clear_error(tmp_path, capsys):
    index = _catalog(tmp_path, {"lib": _core(tmp_path, "lib")})
    code = alp.main(["--root", str(tmp_path / "root"), "--index", str(index), "--progress-fd", "987654", "install", "lib", "--yes"])
    err = capsys.readouterr().err
    assert code == 1
    assert "--progress-fd 987654" in err
