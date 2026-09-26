"""--relocate / @PREFIX@ testleri.

Gerçek `make` gerektiren testler, make yoksa (ör. Windows host) atlanır.
Ağa çıkılmaz: kaynak arşiv yerel dosyadır.
"""

from __future__ import annotations

import io
import json
import shutil
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

needs_make = pytest.mark.skipif(shutil.which("make") is None, reason="make yok")

MAKEFILE = (
    "prefix ?= /usr\n"
    "install:\n"
    "\tmkdir -p $(DESTDIR)$(prefix)/bin $(DESTDIR)$(prefix)/share/demo\n"
    "\tprintf 'data\\n' > $(DESTDIR)$(prefix)/share/demo/data.txt\n"
    "\tprintf '#!/bin/sh\\ncat $(prefix)/share/demo/data.txt\\n' > $(DESTDIR)$(prefix)/bin/demo\n"
    "\tchmod 755 $(DESTDIR)$(prefix)/bin/demo\n"
)


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


def _recipe(tmp_path: Path, make_install: list[str], makefile: str = MAKEFILE) -> dict:
    archive = tmp_path / "demo.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        data = makefile.encode()
        info = tarfile.TarInfo("demo-1.0/Makefile")
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
    recipe = {
        "name": "demo", "version": "1.0",
        "source_url": "demo.tar.gz", "sha256": alp.sha256_of(archive),
        "build": {"configure": ["true"], "make": ["true"], "make_install": make_install},
    }
    (tmp_path / "demo.recipe.json").write_text(json.dumps(recipe), encoding="utf-8")
    return recipe


def test_prefix_token_defaults_to_usr(paths: alp.Paths):
    recipe = {"build": {"configure": ["./configure", "--prefix=@PREFIX@"], "make": ["make"],
                        "make_install": ["make", "install"]}}
    steps = alp._recipe_steps(recipe, paths, "/d")
    assert steps == [["./configure", "--prefix=/usr"], ["make"], ["make", "install", "DESTDIR=/d"]]


def test_prefix_token_follows_root_with_relocate(paths: alp.Paths):
    paths.relocate = True
    recipe = {"build": {"configure": ["true"], "make": ["make"],
                        "make_install": ["make", "install", "prefix=@PREFIX@"]}}
    steps = alp._recipe_steps(recipe, paths, "/d")
    assert steps[2] == ["make", "install", f"prefix={paths.root}/usr", "DESTDIR=/d"]


def test_relocate_is_noop_for_real_root():
    p = alp.Paths.resolve("/")
    p.relocate = True
    assert alp._recipe_prefix(p) == "/usr"


@needs_make
def test_relocated_install_runs_from_root_then_removes(paths: alp.Paths, tmp_path: Path):
    paths.relocate = True
    _recipe(tmp_path, ["make", "install", "prefix=@PREFIX@"])

    record = alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, tmp_path, dry_run=False)

    script = paths.root / "usr/bin/demo"
    assert (paths.root / "usr/share/demo/data.txt").read_text() == "data\n"
    # the installed program points at its data under the root, not at /usr
    assert f"{paths.root}/usr/share/demo/data.txt" in script.read_text()
    # nothing leaked under root/<root path>
    assert not (paths.root / paths.root.relative_to("/")).exists()

    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {"demo": record}}
    alp.remove_package(paths, db, "demo", dry_run=False)
    assert not (paths.root / "usr/bin/demo").exists()


@needs_make
def test_relocated_install_refuses_files_outside_root(paths: alp.Paths, tmp_path: Path):
    paths.relocate = True
    makefile = MAKEFILE + "\tmkdir -p $(DESTDIR)/etc && touch $(DESTDIR)/etc/demo.conf\n"
    _recipe(tmp_path, ["make", "install", "prefix=@PREFIX@"], makefile)

    with pytest.raises(alp.AlpError, match="/etc/demo.conf"):
        alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, tmp_path, dry_run=False)
    assert not (paths.root / "usr/bin/demo").exists()


@needs_make
def test_without_relocate_layout_is_unchanged(paths: alp.Paths, tmp_path: Path):
    _recipe(tmp_path, ["make", "install", "prefix=@PREFIX@"])
    alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, tmp_path, dry_run=False)
    assert "/usr/share/demo/data.txt" in (paths.root / "usr/bin/demo").read_text()
    assert str(paths.root) not in (paths.root / "usr/bin/demo").read_text()


def test_destdir_token_replaces_appended_destdir(paths: alp.Paths):
    paths.relocate = True
    recipe = {"build": {"configure": ["true"], "make": ["make"],
                        "make_install": ["make", "install", "BINDIR=@DESTDIR@@PREFIX@/bin"]}}
    steps = alp._recipe_steps(recipe, paths, "/d")
    assert steps[2] == ["make", "install", f"BINDIR=/d{paths.root}/usr/bin"]


@needs_make
def test_destdir_token_real_install(paths: alp.Paths, tmp_path: Path):
    """tree-style Makefile: DESTDIR is the bin dir, so the recipe splices
    the staging root in itself; the result must land under root/usr/bin."""
    makefile = (
        "DESTDIR=/usr/local/bin\n"
        "install:\n"
        "\tmkdir -p $(DESTDIR)\n"
        "\tprintf '#!/bin/sh\\necho ok\\n' > $(DESTDIR)/demo\n"
        "\tchmod 755 $(DESTDIR)/demo\n"
    )
    paths.relocate = True
    _recipe(tmp_path, ["make", "install", "DESTDIR=@DESTDIR@@PREFIX@/bin"], makefile)
    alp.install_recipe(paths, {"recipe": "demo.recipe.json"}, tmp_path, dry_run=False)
    assert (paths.root / "usr/bin/demo").is_file()
