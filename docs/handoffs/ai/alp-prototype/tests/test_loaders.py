"""Corrupt state files must give 'alp: hata:', not a traceback; read-only
commands must not create the state directory."""
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def test_corrupt_index_is_alp_error(tmp_path):
    bad = tmp_path / "index.json"
    bad.write_text('{"entries": ', encoding="utf-8")
    with pytest.raises(alp.AlpError):
        alp.load_index(bad)


def test_corrupt_db_is_alp_error(tmp_path):
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    paths.ensure()
    paths.db_file.write_text("", encoding="utf-8")
    with pytest.raises(alp.AlpError):
        alp.load_db(paths)


def test_list_does_not_create_state_dir(tmp_path, capsys):
    idx = tmp_path / "index.json"
    idx.write_text('{"entries": {}}', encoding="utf-8")
    root = tmp_path / "root"
    root.mkdir()
    assert alp.main(["--root", str(root), "--index", str(idx), "list"]) == 0
    assert not (root / "var").exists()


def test_main_reports_corrupt_index(tmp_path, capsys):
    idx = tmp_path / "index.json"
    idx.write_text("{", encoding="utf-8")
    assert alp.main(["--root", str(tmp_path), "--index", str(idx), "list"]) == 1
    assert "alp: hata:" in capsys.readouterr().err
