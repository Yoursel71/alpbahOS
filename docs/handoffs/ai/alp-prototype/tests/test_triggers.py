"""Fixed catalogue triggers (NVIDIA-PKG-01 groundwork): "ldconfig" and "depmod" run once after a transaction that
installed, upgraded or removed a package naming them; no other name is accepted. Nothing real runs: subprocess.run
and shutil.which are replaced."""

from __future__ import annotations

import argparse
import subprocess
import tarfile
from pathlib import Path

import pytest

import alp


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    p.trust = alp.TrustPolicy(allow_unsigned=True)
    return p


@pytest.fixture
def ran(monkeypatch):
    calls: list[list[str]] = []

    def run(cmd, **kw):
        calls.append(list(cmd))
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    monkeypatch.setattr(alp.subprocess, "run", run)
    monkeypatch.setattr(alp.shutil, "which", lambda name, **kw: f"/usr/sbin/{name}")
    return calls


def _core(tmp_path: Path, name: str, triggers=None) -> dict:
    archive = tmp_path / f"{name}.tar.gz"
    data = tmp_path / f"{name}-data"
    data.write_bytes(b"x")
    with tarfile.open(archive, "w:gz") as tf:
        tf.add(data, arcname=f"usr/lib/{name}.so.1")
    entry = {"method": "core", "name": name, "version": "1.0.0", "url": archive.name, "sha256": alp.sha256_of(archive)}
    if triggers is not None:
        entry["triggers"] = triggers
    return entry


def _args(name, dry_run=False):
    return argparse.Namespace(name=name, yes=True, dry_run=dry_run, json=False, reinstall=False, cascade=False)


def _kernels(paths, *kvers):
    for kv in kvers:
        Path(paths.root, "usr/lib/modules", kv).mkdir(parents=True)


def test_install_runs_each_trigger_once_for_the_target_root(paths, tmp_path, ran):
    _kernels(paths, "7.1.8-alpbahos", "7.2.0-alpbahos")
    index = {"entries": {"nv": _core(tmp_path, "nv", ["depmod", "ldconfig"]), "lib": _core(tmp_path, "lib", ["ldconfig"])}}
    index["entries"]["nv"]["depends"] = ["lib"]
    assert alp.cmd_install(_args("nv"), paths, index, tmp_path) == 0
    root = str(paths.root)
    assert ran == [["/usr/sbin/ldconfig", "-r", root],
                   ["/usr/sbin/depmod", "-a", "-b", root, "7.1.8-alpbahos"],
                   ["/usr/sbin/depmod", "-a", "-b", root, "7.2.0-alpbahos"]]
    assert alp.load_db(paths)["packages"]["nv"]["triggers"] == ["depmod", "ldconfig"]


def test_no_trigger_no_command(paths, tmp_path, ran):
    index = {"entries": {"plain": _core(tmp_path, "plain")}}
    alp.cmd_install(_args("plain"), paths, index, tmp_path)
    assert ran == []
    assert "triggers" not in alp.load_db(paths)["packages"]["plain"]


def test_dry_run_only_prints(paths, tmp_path, ran, capsys):
    _kernels(paths, "7.1.8-alpbahos")
    index = {"entries": {"nv": _core(tmp_path, "nv", ["depmod"])}}
    alp.cmd_install(_args("nv", dry_run=True), paths, index, tmp_path)
    assert ran == []
    assert "[dry-run] tetikleyici: depmod -a -b" in capsys.readouterr().out


def test_remove_runs_the_removed_package_triggers(paths, tmp_path, ran):
    index = {"entries": {"lib": _core(tmp_path, "lib", ["ldconfig"])}}
    alp.cmd_install(_args("lib"), paths, index, tmp_path)
    ran.clear()
    assert alp.cmd_remove(_args("lib"), paths, index) == 0
    assert ran == [["/usr/sbin/ldconfig", "-r", str(paths.root)]]


def test_live_root_uses_plain_commands(tmp_path, monkeypatch):
    p = alp.Paths.resolve(str(tmp_path / "r"))
    monkeypatch.setattr(p, "root", Path("/"))
    assert alp._trigger_commands(p, "ldconfig") == [["ldconfig"]]


def test_failing_trigger_warns_and_keeps_the_install(paths, tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(alp.shutil, "which", lambda name, **kw: f"/usr/sbin/{name}")
    monkeypatch.setattr(alp.subprocess, "run",
                        lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1, stdout="", stderr="boom"))
    index = {"entries": {"lib": _core(tmp_path, "lib", ["ldconfig"])}}
    assert alp.cmd_install(_args("lib"), paths, index, tmp_path) == 0
    assert "lib" in alp.load_db(paths)["packages"]
    assert "tetikleyici başarısız" in capsys.readouterr().err


@pytest.mark.parametrize("bad", [["rm -rf /"], ["sh"], "ldconfig", [["ldconfig"]]])
def test_catalogue_with_an_unknown_trigger_is_refused(tmp_path, bad):
    index = {"entries": {"x": {**_core(tmp_path, "x"), "triggers": bad}}}
    with pytest.raises(alp.AlpError, match="tanımsız tetikleyici"):
        alp._validate_catalog(index, tmp_path)


def test_unknown_name_in_a_record_is_never_run(paths, ran):
    alp.run_triggers(paths, {"rm", "sh -c x"}, dry_run=False)
    assert ran == []
