"""`alp update` için git katalog yolu (\"source\" alanı olmayan git checkout).

Gerçek git kullanır (yerel bare repo, ağ yok); git yoksa atlanır.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

pytestmark = pytest.mark.skipif(shutil.which("git") is None, reason="git yok")


def _run(cwd: Path, *args: str) -> str:
    return subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def _write_catalog(repo: Path, version: str) -> None:
    (repo / "recipes").mkdir(exist_ok=True)
    recipe = {"name": "demo", "version": version, "source_url": "x.tar.gz", "sha256": "0" * 64,
              "build": {"configure": ["true"], "make": ["true"], "make_install": ["true"]}}
    (repo / "recipes/demo.recipe.json").write_text(json.dumps(recipe), encoding="utf-8")
    index = {"schema_version": 1, "entries": {"demo": {"method": "recipe", "recipe": "recipes/demo.recipe.json"}}}
    (repo / "index.json").write_text(json.dumps(index), encoding="utf-8")


def _commit(repo: Path, message: str) -> None:
    _run(repo, "add", "-A")
    _run(repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", message)


@pytest.fixture
def catalogs(tmp_path: Path):
    """(upstream work tree, local clone) sharing a bare remote."""
    bare = tmp_path / "remote.git"
    _run(tmp_path, "init", "-q", "--bare", "-b", "main", str(bare))
    upstream = tmp_path / "upstream"
    _run(tmp_path, "clone", "-q", str(bare), str(upstream))
    _write_catalog(upstream, "1.0")
    _commit(upstream, "v1")
    _run(upstream, "push", "-q", "origin", "HEAD:main")
    local = tmp_path / "local"
    _run(tmp_path, "clone", "-q", str(bare), str(local))
    return upstream, local


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


def _update(paths: alp.Paths, local: Path, dry_run: bool = False) -> int:
    index_path = local / "index.json"
    args = argparse.Namespace(source=None, sha256=None, dry_run=dry_run)
    return alp.cmd_update(args, paths, index_path, alp.load_index(index_path))


def _publish(upstream: Path, version: str) -> None:
    _write_catalog(upstream, version)
    _commit(upstream, f"v{version}")
    _run(upstream, "push", "-q", "origin", "HEAD:main")


def test_up_to_date(paths, catalogs, capsys):
    _, local = catalogs
    assert _update(paths, local) == 0
    assert "Katalog zaten güncel." in capsys.readouterr().out


def test_fast_forwards_and_reports_changes(paths, catalogs, capsys):
    upstream, local = catalogs
    _publish(upstream, "2.0")
    assert _update(paths, local) == 0
    assert "değişti   demo 1.0 -> 2.0" in capsys.readouterr().out
    assert json.loads((local / "recipes/demo.recipe.json").read_text())["version"] == "2.0"


def test_dry_run_changes_nothing(paths, catalogs, capsys):
    upstream, local = catalogs
    _publish(upstream, "2.0")
    before = _run(local, "rev-parse", "HEAD")
    assert _update(paths, local, dry_run=True) == 0
    assert _run(local, "rev-parse", "HEAD") == before
    assert "[dry-run]" in capsys.readouterr().out


def test_refuses_dirty_checkout(paths, catalogs):
    upstream, local = catalogs
    _publish(upstream, "2.0")
    (local / "index.json").write_text((local / "index.json").read_text() + "\n", encoding="utf-8")
    with pytest.raises(alp.AlpError, match="kaydedilmemiş değişiklik"):
        _update(paths, local)


def test_refuses_diverged_checkout(paths, catalogs):
    upstream, local = catalogs
    _publish(upstream, "2.0")
    _write_catalog(local, "1.5")
    _commit(local, "local")
    with pytest.raises(alp.AlpError, match="ayrışmış"):
        _update(paths, local)


def test_invalid_new_catalog_is_rolled_back(paths, catalogs):
    upstream, local = catalogs
    (upstream / "recipes/demo.recipe.json").unlink()
    _commit(upstream, "broken")
    _run(upstream, "push", "-q", "origin", "HEAD:main")
    before = _run(local, "rev-parse", "HEAD")
    with pytest.raises(alp.AlpError, match="eski hâline"):
        _update(paths, local)
    assert _run(local, "rev-parse", "HEAD") == before
    assert (local / "recipes/demo.recipe.json").is_file()
