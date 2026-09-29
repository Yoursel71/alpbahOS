"""I/O and JSON errors are clean `alp: hata:` messages, and read-only commands stay read-only.

Found in the 29 Sep 2026 audit (handoff 020):
  * main() only caught AlpError/CalledProcessError, so a missing or corrupt index
    (FileNotFoundError, JSONDecodeError) or an unwritable --root escaped as a Python
    traceback;
  * `list`, `info` and `check` called paths.ensure(), so a plain `alp list` created
    (or failed to create) the state directories;
  * alp_packagekit_backend.alp_search() read "exit 1 with empty stdout" as "no matches",
    so a broken index made store searches silently return nothing.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402
import alp_packagekit_backend as pkb  # noqa: E402

ALP_PY = Path(__file__).resolve().parent.parent / "alp.py"
NOT_ROOT = os.name == "posix" and hasattr(os, "geteuid") and os.geteuid() != 0


def _index(tmp_path: Path) -> Path:
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"entries": {}}), encoding="utf-8")
    return index


def test_missing_index_is_a_clean_error(tmp_path, capsys):
    rc = alp.main(["--root", str(tmp_path / "root"), "--index", str(tmp_path / "nope.json"), "list"])
    err = capsys.readouterr().err
    assert rc == 1
    assert err.startswith("alp: hata:") and "nope.json" in err
    assert "Traceback" not in err


def test_corrupt_index_is_a_clean_error(tmp_path, capsys):
    bad = tmp_path / "index.json"
    bad.write_text("{bad", encoding="utf-8")
    rc = alp.main(["--root", str(tmp_path / "root"), "--index", str(bad), "search", "x"])
    err = capsys.readouterr().err
    assert rc == 1
    assert err.startswith("alp: hata:")
    assert "Traceback" not in err


@pytest.mark.parametrize("argv", [["list"], ["check"], ["info", "nothing"]])
def test_read_only_commands_do_not_create_state(tmp_path, argv):
    root = tmp_path / "root"
    alp.main(["--root", str(root), "--index", str(_index(tmp_path)), *argv])
    assert not root.exists(), "a read-only command must not create the root or its state directories"


@pytest.mark.skipif(not NOT_ROOT, reason="permission bits do not restrict root")
def test_read_only_command_works_on_an_unwritable_root(tmp_path, capsys):
    root = tmp_path / "root"
    root.mkdir()
    root.chmod(0o555)
    try:
        assert alp.main(["--root", str(root), "--index", str(_index(tmp_path)), "list"]) == 0
        assert "Kurulu paket yok" in capsys.readouterr().out
    finally:
        root.chmod(0o755)


@pytest.mark.skipif(not NOT_ROOT, reason="permission bits do not restrict root")
def test_write_command_on_an_unwritable_root_is_a_clean_error(tmp_path, capsys):
    root = tmp_path / "root"
    root.mkdir()
    root.chmod(0o555)
    try:
        rc = alp.main(["--root", str(root), "--index", str(_index(tmp_path)), "autoremove", "--yes"])
        err = capsys.readouterr().err
    finally:
        root.chmod(0o755)
    assert rc == 1
    assert err.startswith("alp: hata:") and "Traceback" not in err


def test_backend_search_reports_a_broken_index_instead_of_no_matches(tmp_path):
    with pytest.raises(pkb.AlpBackendError):
        pkb.alp_search(ALP_PY, tmp_path / "root", tmp_path / "nope.json", "x")


def test_backend_search_still_returns_an_empty_list_for_no_matches(tmp_path):
    assert pkb.alp_search(ALP_PY, tmp_path / "root", _index(tmp_path), "nothing-matches") == []
