from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import alp  # noqa: E402


def _root_with_index(tmp_path: Path) -> Path:
    root = tmp_path / "root"
    (root / "usr/share/alp").mkdir(parents=True)
    (root / "usr/share/alp/index.json").write_text(json.dumps({"schema_version": 1, "entries": {}}), encoding="utf-8")
    return root


def test_default_index_is_used_without_index_argument(tmp_path):
    root = _root_with_index(tmp_path)
    paths = alp.Paths.resolve(str(root))
    assert alp.resolve_index_path(None, paths) == (root / "usr/share/alp/index.json").resolve()


def test_explicit_index_wins_over_default(tmp_path):
    root = _root_with_index(tmp_path)
    other = tmp_path / "other.json"
    other.write_text("{}", encoding="utf-8")
    paths = alp.Paths.resolve(str(root))
    assert alp.resolve_index_path(str(other), paths) == other.resolve()


def test_missing_default_index_is_refused(tmp_path):
    paths = alp.Paths.resolve(str(tmp_path / "empty-root"))
    with pytest.raises(alp.AlpError):
        alp.resolve_index_path(None, paths)
