"""`alp protect --dry-run` must say it changed nothing.

Found in the 29 Sep 2026 audit (handoff 020): with --dry-run the db was left alone but
the command still printed "<paket> korumalı olarak işaretlendi.", as if it had been done.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


@pytest.fixture
def root(tmp_path):
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    paths.ensure()
    db = alp.load_db(paths)
    db["packages"]["foo"] = {"name": "foo", "version": "1", "method": "core", "files": [], "symlinks": []}
    alp.save_db(paths, db)
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"entries": {}}), encoding="utf-8")
    return paths, index


def _protected(paths) -> bool:
    return bool(alp.load_db(paths)["packages"]["foo"].get("protected"))


@pytest.mark.parametrize("verb, done", [("protect", "korumalı olarak işaretlendi"), ("unprotect", "artık korumalı değil")])
def test_dry_run_reports_what_would_happen_and_changes_nothing(root, capsys, verb, done):
    paths, index = root
    assert alp.main(["--root", str(paths.root), "--index", str(index), "--dry-run", verb, "foo"]) == 0
    out = capsys.readouterr().out
    assert out.startswith("[dry-run]")
    assert done not in out, "dry-run must not claim the change was made"
    assert not _protected(paths)


def test_real_protect_and_unprotect_still_report_and_persist(root, capsys):
    paths, index = root
    base = ["--root", str(paths.root), "--index", str(index)]
    assert alp.main([*base, "protect", "foo"]) == 0
    assert "korumalı olarak işaretlendi" in capsys.readouterr().out and _protected(paths)
    assert alp.main([*base, "unprotect", "foo"]) == 0
    assert "artık korumalı değil" in capsys.readouterr().out and not _protected(paths)
