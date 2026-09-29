"""Catalog <-> engine contract (M10 blocker "M08 kurulum/kaldırma").

The catalog is fetched on its own (`alp update`), the engine is installed
separately, and they drifted apart on the target: the catalog's recipes said
`--prefix=@PREFIX@`, the installed alp predated the placeholder, and
`pkcon install htop` died in ./configure. Discover, meanwhile, showed
"Version: 0" and "Size: 16.0 EiB" because `alp info` gave the PackageKit
helper nothing better to show.

Same rules as the other suites: no network, real tarballs under tmp_path.
"""

from __future__ import annotations

import io
import json
import sys
import tarfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


def _recipe_catalog(tmp_path: Path, configure: list[str], **extra_recipe) -> Path:
    """A one-recipe catalog whose source archive is a local tarball."""
    archive = tmp_path / "demo-2.5.tar.gz"
    with tarfile.open(archive, "w:gz") as tf:
        data = b"install:\n\ttrue\n"
        info = tarfile.TarInfo("demo-2.5/Makefile")
        info.size = len(data)
        tf.addfile(info, io.BytesIO(data))
    recipes = tmp_path / "recipes"
    recipes.mkdir(exist_ok=True)
    recipe = {
        "name": "demo", "version": "2.5",
        "source_url": "demo-2.5.tar.gz", "sha256": alp.sha256_of(archive),
        "build": {"configure": configure, "make": ["true"], "make_install": ["make", "install"]},
        **extra_recipe,
    }
    (recipes / "demo.recipe.json").write_text(json.dumps(recipe), encoding="utf-8")
    index = tmp_path / "index.json"
    index.write_text(json.dumps({"schema_version": 1, "entries": {
        "demo": {"method": "recipe", "recipe": "recipes/demo.recipe.json", "description": "Deneme paketi"},
    }}), encoding="utf-8")
    return index


def _cli(capsys, *argv) -> tuple[int, str, str]:
    code = alp.main(list(argv))
    captured = capsys.readouterr()
    return code, captured.out, captured.err


# --------------------------------------------------------------------------
# Unknown placeholders fail before anything is downloaded or built
# --------------------------------------------------------------------------

def test_unknown_placeholder_is_refused_with_a_clear_message(tmp_path):
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    recipe = {"name": "demo", "build": {
        "configure": ["./configure", "--libdir=@LIBDIR@"], "make": ["make"], "make_install": ["make", "install"]}}
    with pytest.raises(alp.AlpError) as excinfo:
        alp._recipe_steps(recipe, paths, "/stage")
    message = str(excinfo.value)
    assert "@LIBDIR@" in message and "demo" in message
    assert "güncelleyin" in message and "indirilmedi" in message


def test_known_placeholders_still_expand_to_absolute_paths(tmp_path):
    """The exact recipe form the catalog ships (htop): configure must see /usr."""
    paths = alp.Paths.resolve(str(tmp_path / "root"))
    recipe = {"name": "htop", "build": {
        "configure": ["./configure", "--prefix=@PREFIX@"], "make": ["make"], "make_install": ["make", "install"]}}
    configure, make, make_install = alp._recipe_steps(recipe, paths, "/stage")
    assert configure == ["./configure", "--prefix=/usr"]
    assert make == ["make"]
    assert make_install == ["make", "install", "DESTDIR=/stage"]


def test_install_with_unknown_placeholder_never_reaches_download_or_build(tmp_path, capsys):
    index = _recipe_catalog(tmp_path, ["./configure", "--prefix=@PREFIX@", "--with=@FUTURE@"])
    # A source that cannot be fetched: if the guard ran after the download,
    # the error would be about the missing archive, not the placeholder.
    (tmp_path / "demo-2.5.tar.gz").unlink()
    root = tmp_path / "root"
    code, _, err = _cli(capsys, "--root", str(root), "--index", str(index), "install", "demo", "--yes")
    assert code != 0
    assert "@FUTURE@" in err
    assert not list(root.rglob("*.build.log"))


def test_dry_run_reports_the_unknown_placeholder_too(tmp_path, capsys):
    index = _recipe_catalog(tmp_path, ["./configure", "--prefix=@PREFIX@", "--with=@FUTURE@"])
    code, _, err = _cli(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "--dry-run", "install", "demo")
    assert code != 0
    assert "@FUTURE@" in err


# --------------------------------------------------------------------------
# info / search --json carry version, license, homepage, size when known
# --------------------------------------------------------------------------

def test_info_of_uninstalled_recipe_reports_the_recipe_version(tmp_path, capsys):
    index = _recipe_catalog(tmp_path, ["./configure", "--prefix=@PREFIX@"],
                            license="GPL-2.0-or-later", homepage="https://example.org/demo")
    code, out, _ = _cli(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "info", "demo")
    assert code == 0
    info = json.loads(out)
    assert info["status"] == "not-installed"
    assert info["version"] == "2.5"
    assert info["license"] == "GPL-2.0-or-later"
    assert info["homepage"] == "https://example.org/demo"
    assert "size" not in info  # the catalog did not say; alp does not guess


def test_search_json_rows_carry_the_same_metadata(tmp_path, capsys):
    index = _recipe_catalog(tmp_path, ["./configure"])
    code, out, _ = _cli(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "--json", "search", "demo")
    assert code == 0
    (row,) = json.loads(out)
    assert row == {"name": "demo", "method": "recipe", "description": "Deneme paketi", "version": "2.5"}


def test_entry_level_fields_win_and_size_passes_through(tmp_path):
    index = _recipe_catalog(tmp_path, ["./configure"], license="MIT")
    entry = {"method": "recipe", "recipe": "recipes/demo.recipe.json", "version": "9.9", "size": 4096}
    meta = alp._entry_metadata(entry, index.parent)
    assert meta == {"version": "9.9", "license": "MIT", "size": 4096}


@pytest.mark.parametrize("bad_size", [True, -1, "4096", 1.5, None])
def test_invalid_size_is_dropped_not_coerced(tmp_path, bad_size):
    index = _recipe_catalog(tmp_path, ["./configure"])
    entry = {"method": "recipe", "recipe": "recipes/demo.recipe.json", "size": bad_size}
    assert "size" not in alp._entry_metadata(entry, index.parent)


def test_missing_or_corrupt_recipe_only_drops_its_fields(tmp_path, capsys):
    index = _recipe_catalog(tmp_path, ["./configure"])
    recipe_file = tmp_path / "recipes" / "demo.recipe.json"
    recipe_file.write_text("{ bozuk", encoding="utf-8")
    code, out, _ = _cli(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "--json", "search", "demo")
    assert code == 0
    (row,) = json.loads(out)
    assert row["name"] == "demo" and "version" not in row
    recipe_file.unlink()
    code, out, _ = _cli(capsys, "--root", str(tmp_path / "root"), "--index", str(index), "info", "demo")
    assert code == 0 and "version" not in json.loads(out)


def test_flatpak_entries_have_no_invented_version(tmp_path):
    entry = {"method": "flatpak", "flatpak_ref": "org.example.App", "remote": "flathub", "description": "x"}
    assert alp._entry_metadata(entry, tmp_path) == {}


def test_metadata_without_an_index_dir_is_entry_only():
    """Callers that predate index_dir (cmd_search(index, term)) keep working."""
    assert alp._entry_metadata({"method": "recipe", "recipe": "r.json", "version": "1"}, None) == {"version": "1"}
