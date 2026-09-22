"""Automated tests for alp.py.

Durum: bu test dosyası bu oturumda gerçekten çalıştırıldı (pytest 8.4.2,
Windows host). Gerçek ağa hiç çıkmaz -- urllib.request.urlopen her yerde
monkeypatch'lenir; yalnızca yerel dosyalar ve tmp_path kullanılır. Bu, hem
hız hem tekrarlanabilirlik için bilinçli bir tercih: checksum/kilit/db
mantığının ağdan bağımsız doğrulanması gerekiyor, gerçek indirme davranışı
zaten proposal belgesinde (§8) ayrı ve açıkça "gerçek ağdan" diye
işaretlenmiş durumda.

configure/make/make install ve flatpak install/uninstall'ın GERÇEK
çalıştırılması bu test setinin kapsamı DIŞINDADIR (bu hostta o araçlar
yok); sadece "gerekli araç bulunamadı" hata yolu test edilir.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import sys
import tarfile
import time
import urllib.error
from pathlib import Path
from unittest import mock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _make_tar(tmp_path: Path, name: str, members: dict[str, bytes]) -> Path:
    """Build a real .tar.gz with the given {relpath: content} files, each
    under its own directory entries (mirrors how real release tarballs and
    the repo's own demo archive are laid out)."""
    archive = tmp_path / name
    with tarfile.open(archive, "w:gz") as tf:
        seen_dirs: set[str] = set()
        for relpath, content in members.items():
            parts = Path(relpath).parts[:-1]
            acc = ""
            for part in parts:
                acc = f"{acc}{part}/" if acc else f"{part}/"
                if acc not in seen_dirs:
                    seen_dirs.add(acc)
                    d = tarfile.TarInfo(acc.rstrip("/"))
                    d.type = tarfile.DIRTYPE
                    d.mode = 0o755
                    tf.addfile(d)
            info = tarfile.TarInfo(relpath)
            info.size = len(content)
            tf.addfile(info, io.BytesIO(content))
    return archive


def _make_malicious_tar(tmp_path: Path, name: str) -> Path:
    """A tarball with a path-traversal member (../evil.txt)."""
    archive = tmp_path / name
    with tarfile.open(archive, "w:gz") as tf:
        content = b"pwned"
        info = tarfile.TarInfo("../evil.txt")
        info.size = len(content)
        tf.addfile(info, io.BytesIO(content))
    return archive


@pytest.fixture
def paths(tmp_path: Path) -> alp.Paths:
    p = alp.Paths.resolve(str(tmp_path / "root"))
    p.ensure()
    return p


# --------------------------------------------------------------------------
# Paths / db / lock
# --------------------------------------------------------------------------

def test_paths_resolve_creates_expected_layout(tmp_path: Path):
    p = alp.Paths.resolve(str(tmp_path / "root"))
    assert p.db_file == p.state_dir / "db.json"
    assert p.lock_file == p.state_dir / "alp.lock"
    assert p.state_dir == p.root / "var/lib/alp"
    assert p.log_dir == p.root / "var/log/alp"


def test_db_lock_blocks_second_writer(paths: alp.Paths):
    with alp.DbLock(paths.lock_file):
        assert paths.lock_file.exists()
        with pytest.raises(alp.AlpError, match="kilitli"):
            with alp.DbLock(paths.lock_file):
                pass
    # lock released after the outer `with` exits
    assert not paths.lock_file.exists()


def test_db_lock_releases_even_on_exception(paths: alp.Paths):
    with pytest.raises(ValueError):
        with alp.DbLock(paths.lock_file):
            raise ValueError("boom")
    assert not paths.lock_file.exists()


def test_load_db_default_when_missing(paths: alp.Paths):
    db = alp.load_db(paths)
    assert db == {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {}}


def test_load_db_rejects_wrong_schema_version(paths: alp.Paths):
    paths.db_file.write_text(json.dumps({"schema_version": 999, "packages": {}}), encoding="utf-8")
    with pytest.raises(alp.AlpError, match="şema"):
        alp.load_db(paths)


def test_save_db_is_atomic_and_stamps_updated_at(paths: alp.Paths):
    db = alp.load_db(paths)
    db["packages"]["x"] = {"version": "1"}
    alp.save_db(paths, db)
    assert not paths.db_file.with_suffix(".json.tmp").exists()  # tmp file renamed away
    reloaded = alp.load_db(paths)
    assert reloaded["packages"] == {"x": {"version": "1"}}
    assert reloaded["updated_at"] is not None


# --------------------------------------------------------------------------
# resolve_source_url
# --------------------------------------------------------------------------

def test_resolve_source_url_http_passthrough(tmp_path: Path):
    url = "https://example.com/pkg.tar.gz"
    assert alp.resolve_source_url(url, tmp_path) == url


def test_resolve_source_url_local_relative_resolves_against_base_dir(tmp_path: Path):
    result = alp.resolve_source_url("core/pkg.tar.gz", tmp_path)
    assert result == str(tmp_path / "core/pkg.tar.gz")


def test_resolve_source_url_local_absolute_is_unchanged(tmp_path: Path):
    absolute = str(tmp_path / "pkg.tar.gz")
    assert alp.resolve_source_url(absolute, tmp_path / "unrelated") == absolute


# --------------------------------------------------------------------------
# fetch() -- checksum verification, no real network (urlopen monkeypatched)
# --------------------------------------------------------------------------

def test_fetch_local_file_checksum_match(tmp_path: Path):
    src = tmp_path / "src.bin"
    data = b"hello alpbahOS"
    src.write_bytes(data)
    dest = tmp_path / "out" / "dest.bin"
    alp.fetch(str(src), dest, _sha256_bytes(data))
    assert dest.read_bytes() == data


def test_fetch_checksum_mismatch_deletes_file_and_raises(tmp_path: Path):
    src = tmp_path / "src.bin"
    src.write_bytes(b"real content")
    dest = tmp_path / "out" / "dest.bin"
    with pytest.raises(alp.AlpError, match="Checksum uyuşmadı"):
        alp.fetch(str(src), dest, "0" * 64)
    assert not dest.exists()


def test_fetch_http_success_uses_timeout_and_verifies_checksum(tmp_path: Path):
    """Regression test for finding #3 (no timeout on urlopen)."""
    data = b"fake remote payload"
    fake_resp = io.BytesIO(data)

    class _CM:
        def __enter__(self):
            return fake_resp

        def __exit__(self, *a):
            return False

    dest = tmp_path / "out" / "dest.bin"
    with mock.patch.object(alp.urllib.request, "urlopen", return_value=_CM()) as m:
        alp.fetch("https://example.com/pkg.tar.gz", dest, _sha256_bytes(data))
    assert dest.read_bytes() == data
    m.assert_called_once()
    _, kwargs = m.call_args
    assert kwargs.get("timeout") == alp.DOWNLOAD_TIMEOUT_S


def test_fetch_http_network_error_raises_clean_alperror_not_traceback(tmp_path: Path):
    """Regression test for finding #3: OSError/timeout must become AlpError,
    not an unhandled traceback."""
    dest = tmp_path / "out" / "dest.bin"
    with mock.patch.object(
        alp.urllib.request, "urlopen", side_effect=urllib.error.URLError("timed out")
    ):
        with pytest.raises(alp.AlpError, match="İndirme başarısız"):
            alp.fetch("https://example.com/pkg.tar.gz", dest, "0" * 64)


# --------------------------------------------------------------------------
# safe_extract -- path traversal rejection
# --------------------------------------------------------------------------

def test_safe_extract_normal_archive(tmp_path: Path):
    archive = _make_tar(tmp_path, "ok.tar.gz", {"usr/bin/tool": b"binary-content"})
    dest = tmp_path / "extracted"
    names = alp.safe_extract(archive, dest)
    assert "usr/bin/tool" in names
    assert (dest / "usr/bin/tool").read_bytes() == b"binary-content"


def test_safe_extract_rejects_path_traversal(tmp_path: Path):
    archive = _make_malicious_tar(tmp_path, "evil.tar.gz")
    dest = tmp_path / "extracted"
    # Python 3.12+'s filter="data" silently raises tarfile.FilterError, which
    # is a subclass of tarfile.TarError, not caught as our AlpError on some
    # versions -- accept either our explicit AlpError (pre-3.12 fallback
    # path) or tarfile's own rejection as a pass, but the member must NEVER
    # land outside dest.
    try:
        alp.safe_extract(archive, dest)
    except (alp.AlpError, tarfile.TarError):
        pass
    assert not (tmp_path / "evil.txt").exists()


# --------------------------------------------------------------------------
# _merge_destdir -- regression test for finding #2 (orphaned directories)
# --------------------------------------------------------------------------

def test_merge_destdir_records_directories_not_just_files(tmp_path: Path):
    destdir = tmp_path / "destdir"
    (destdir / "usr/share/doc/pkg").mkdir(parents=True)
    (destdir / "usr/bin").mkdir(parents=True)
    (destdir / "usr/bin/tool").write_bytes(b"x")
    (destdir / "usr/share/doc/pkg/readme").write_bytes(b"y")

    root = tmp_path / "root"
    installed = alp._merge_destdir(destdir, root, dry_run=False)

    # both leaf files...
    assert "/usr/bin/tool" in installed
    assert "/usr/share/doc/pkg/readme" in installed
    # ...AND every directory that was created, so remove_package can clean
    # them up (this is exactly what finding #2 said was missing).
    assert "/usr/bin" in installed
    assert "/usr/share/doc/pkg" in installed
    assert "/usr/share/doc" in installed
    assert "/usr/share" in installed
    assert "/usr" in installed
    assert (root / "usr/bin/tool").read_bytes() == b"x"


def test_merge_destdir_dry_run_does_not_copy_files(tmp_path: Path):
    destdir = tmp_path / "destdir"
    (destdir / "usr/bin").mkdir(parents=True)
    (destdir / "usr/bin/tool").write_bytes(b"x")
    root = tmp_path / "root"

    installed = alp._merge_destdir(destdir, root, dry_run=True)

    assert "/usr/bin/tool" in installed  # still reported
    assert not (root / "usr/bin/tool").exists()  # but nothing copied


# --------------------------------------------------------------------------
# remove_package -- end-to-end: directories left behind must be cleaned up
# --------------------------------------------------------------------------

def test_remove_package_cleans_up_files_and_now_empty_directories(paths: alp.Paths, tmp_path: Path):
    destdir = tmp_path / "destdir"
    (destdir / "usr/share/doc/pkg").mkdir(parents=True)
    (destdir / "usr/share/doc/pkg/readme").write_bytes(b"y")
    installed_files = alp._merge_destdir(destdir, paths.root, dry_run=False)

    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {
        "pkg": {"method": "recipe", "files": installed_files, "flatpak_ref": None}
    }}

    alp.remove_package(paths, db, "pkg", dry_run=False)

    assert "pkg" not in db["packages"]
    assert not (paths.root / "usr/share/doc/pkg").exists()
    assert not (paths.root / "usr/share/doc").exists()
    assert not (paths.root / "usr/share").exists()
    assert not (paths.root / "usr").exists()


def test_remove_package_unknown_name_raises(paths: alp.Paths):
    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {}}
    with pytest.raises(alp.AlpError, match="Kurulu değil"):
        alp.remove_package(paths, db, "nope", dry_run=False)


# --------------------------------------------------------------------------
# install_recipe / install_core dry-run -- regression test for finding #1
# --------------------------------------------------------------------------

def test_install_core_dry_run_never_calls_fetch(paths: alp.Paths, tmp_path: Path):
    entry = {"name": "theme", "version": "1.0.0", "url": "core/theme.tar.gz", "sha256": "0" * 64}
    with mock.patch.object(alp, "fetch") as fetch_mock, mock.patch.object(alp, "safe_extract") as extract_mock:
        record = alp.install_core(paths, entry, tmp_path, dry_run=True)
    fetch_mock.assert_not_called()
    extract_mock.assert_not_called()
    assert record["status"] == "would-install"
    assert record["files"] == []


def test_install_recipe_dry_run_never_calls_fetch(paths: alp.Paths, tmp_path: Path):
    recipe = {
        "name": "htop", "version": "3.3.0",
        "source_url": "https://example.com/htop.tar.xz", "sha256": "0" * 64,
        "build": {"configure": ["./configure"], "make": ["make"], "make_install": ["make", "install"]},
    }
    recipe_path = tmp_path / "htop.recipe.json"
    recipe_path.write_text(json.dumps(recipe), encoding="utf-8")
    entry = {"recipe": "htop.recipe.json"}

    with mock.patch.object(alp, "fetch") as fetch_mock, mock.patch.object(alp, "safe_extract") as extract_mock:
        record = alp.install_recipe(paths, entry, tmp_path, dry_run=True)
    fetch_mock.assert_not_called()
    extract_mock.assert_not_called()
    assert record["status"] == "would-install"
    assert record["files"] == []


def test_install_core_dry_run_leaves_cache_dir_empty(paths: alp.Paths, tmp_path: Path):
    """End-to-end (no mocks) proof that --dry-run truly touches nothing:
    a REAL local source is available, but dry-run must still not read it
    into cache."""
    content = b"theme payload"
    src = tmp_path / "theme.tar.gz"
    src.write_bytes(content)
    entry = {"name": "theme", "version": "1.0.0", "url": "theme.tar.gz", "sha256": _sha256_bytes(content)}

    alp.install_core(paths, entry, tmp_path, dry_run=True)

    assert list(paths.cache_dir.iterdir()) == []


# --------------------------------------------------------------------------
# install_core / install_recipe -- real (non-dry-run) end-to-end
# --------------------------------------------------------------------------

def test_install_core_real_end_to_end_then_remove(paths: alp.Paths, tmp_path: Path):
    archive = _make_tar(tmp_path, "theme.tar.gz", {
        "usr/share/themes/alpbah-solid/theme.conf": b"dark=true\n",
    })
    entry = {"name": "theme", "version": "1.0.0", "url": "theme.tar.gz", "sha256": alp.sha256_of(archive)}

    record = alp.install_core(paths, entry, tmp_path, dry_run=False)
    assert record["status"] == "installed"
    installed_path = paths.root / "usr/share/themes/alpbah-solid/theme.conf"
    assert installed_path.read_bytes() == b"dark=true\n"

    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {"theme": record}}
    alp.remove_package(paths, db, "theme", dry_run=False)
    assert not (paths.root / "usr/share/themes").exists()


def test_install_recipe_real_run_fails_cleanly_without_toolchain(paths: alp.Paths, tmp_path: Path):
    """On a host with no configure/make (like this one), a real (non
    dry-run) recipe install must fail with a clean AlpError identifying
    the missing tool -- not download anything unverified or crash."""
    src_files = {"htop-3.3.0/configure": b"#!/bin/sh\necho fake\n"}
    archive = _make_tar(tmp_path, "htop.tar.xz", src_files)
    recipe = {
        "name": "htop", "version": "3.3.0",
        "source_url": "htop.tar.xz", "sha256": alp.sha256_of(archive),
        "build": {
            "configure": ["./definitely-not-a-real-binary-xyz"],
            "make": ["make"], "make_install": ["make", "install"],
        },
    }
    recipe_path = tmp_path / "htop.recipe.json"
    recipe_path.write_text(json.dumps(recipe), encoding="utf-8")

    with pytest.raises(alp.AlpError, match="Gerekli araç bulunamadı"):
        alp.install_recipe(paths, {"recipe": "htop.recipe.json"}, tmp_path, dry_run=False)


def test_install_recipe_real_run_rejects_bad_checksum_before_any_build(paths: alp.Paths, tmp_path: Path):
    archive = _make_tar(tmp_path, "htop.tar.xz", {"htop-3.3.0/configure": b"x"})
    recipe = {
        "name": "htop", "version": "3.3.0",
        "source_url": "htop.tar.xz", "sha256": "0" * 64,  # deliberately wrong
        "build": {"configure": ["./configure"], "make": ["make"], "make_install": ["make", "install"]},
    }
    (tmp_path / "htop.recipe.json").write_text(json.dumps(recipe), encoding="utf-8")

    with pytest.raises(alp.AlpError, match="Checksum uyuşmadı"):
        alp.install_recipe(paths, {"recipe": "htop.recipe.json"}, tmp_path, dry_run=False)
    # nothing extracted/built after a checksum failure
    assert not any(paths.cache_dir.glob("build-*"))


# --------------------------------------------------------------------------
# CLI-level: cmd_install / cmd_search / cmd_list
# --------------------------------------------------------------------------

def _index(tmp_path: Path, entries: dict) -> tuple[dict, Path]:
    return {"schema_version": 1, "entries": entries}, tmp_path


def test_cmd_install_rejects_unknown_package(paths: alp.Paths, tmp_path: Path):
    import argparse
    args = argparse.Namespace(name="ghost", dry_run=False, reinstall=False)
    index, index_dir = _index(tmp_path, {})
    with pytest.raises(alp.AlpError, match="Bilinmeyen paket"):
        alp.cmd_install(args, paths, index, index_dir)


def test_cmd_install_skips_when_already_installed_without_reinstall(paths: alp.Paths, tmp_path: Path, capsys):
    import argparse
    archive = _make_tar(tmp_path, "theme.tar.gz", {"usr/share/x": b"y"})
    entries = {"theme": {"method": "core", "name": "theme", "version": "1.0.0",
                          "url": "theme.tar.gz", "sha256": alp.sha256_of(archive)}}
    index, index_dir = _index(tmp_path, entries)
    args = argparse.Namespace(name="theme", dry_run=False, reinstall=False)

    assert alp.cmd_install(args, paths, index, index_dir) == 0
    capsys.readouterr()
    assert alp.cmd_install(args, paths, index, index_dir) == 0
    out = capsys.readouterr().out
    assert "zaten kurulu" in out


def test_cmd_search_finds_substring_case_insensitive(tmp_path: Path):
    index = {"entries": {"Firefox": {"method": "flatpak"}, "htop": {"method": "recipe"}}}
    assert alp.cmd_search(index, "fire") == 0
    assert alp.cmd_search(index, "zzz") == 1


def test_cmd_list_reports_no_packages_when_empty(paths: alp.Paths, capsys):
    assert alp.cmd_list(alp.load_db(paths)) == 0
    assert "Kurulu paket yok" in capsys.readouterr().out


# --------------------------------------------------------------------------
# --json output (design/packagekit-integration.md §2 precondition)
# --------------------------------------------------------------------------

def test_cmd_search_json_output_is_parseable(capsys):
    index = {"entries": {"htop": {"method": "recipe"}, "firefox": {"method": "flatpak"}}}
    assert alp.cmd_search(index, "top", as_json=True) == 0
    out = json.loads(capsys.readouterr().out)
    assert out == [{"name": "htop", "method": "recipe"}]


def test_cmd_search_json_no_hits_returns_empty_array_and_exit_1(capsys):
    index = {"entries": {"htop": {"method": "recipe"}}}
    assert alp.cmd_search(index, "zzz", as_json=True) == 1
    assert json.loads(capsys.readouterr().out) == []


def test_cmd_list_json_output_is_parseable(paths: alp.Paths, capsys):
    db = alp.load_db(paths)
    db["packages"]["htop"] = {"version": "3.3.0", "method": "recipe", "status": "installed"}
    assert alp.cmd_list(db, as_json=True) == 0
    out = json.loads(capsys.readouterr().out)
    assert out == [{"name": "htop", "version": "3.3.0", "method": "recipe", "status": "installed"}]


# --------------------------------------------------------------------------
# upgrade_core / upgrade_recipe -- config protection (.alpnew/.alpsave)
# --------------------------------------------------------------------------

def _install_core_v1_with_config(paths: alp.Paths, tmp_path: Path, config_content: bytes = b"dark=true\n"):
    archive = _make_tar(tmp_path, "theme-1.0.0.tar.gz", {
        "usr/share/themes/alpbah/theme.conf": config_content,
        "usr/share/themes/alpbah/README": b"static, never changes\n",
    })
    entry = {
        "name": "theme", "version": "1.0.0", "url": "theme-1.0.0.tar.gz",
        "sha256": alp.sha256_of(archive),
        "config_files": ["/usr/share/themes/alpbah/theme.conf"],
    }
    record = alp.install_core(paths, entry, tmp_path, dry_run=False)
    return record


def test_upgrade_core_overwrites_untouched_config(paths: alp.Paths, tmp_path: Path):
    old = _install_core_v1_with_config(paths, tmp_path)
    assert old["config_hashes"]["/usr/share/themes/alpbah/theme.conf"] == alp.sha256_of(
        paths.root / "usr/share/themes/alpbah/theme.conf"
    )

    new_archive = _make_tar(tmp_path, "theme-2.0.0.tar.gz", {
        "usr/share/themes/alpbah/theme.conf": b"dark=false\n",  # new upstream default
        "usr/share/themes/alpbah/README": b"static, never changes\n",
    })
    entry = {
        "name": "theme", "version": "2.0.0", "url": "theme-2.0.0.tar.gz",
        "sha256": alp.sha256_of(new_archive),
        "config_files": ["/usr/share/themes/alpbah/theme.conf"],
    }

    new_record = alp.upgrade_core(paths, entry, tmp_path, old, dry_run=False)

    assert new_record["version"] == "2.0.0"
    conf = paths.root / "usr/share/themes/alpbah/theme.conf"
    assert conf.read_bytes() == b"dark=false\n"  # untouched -> silently upgraded
    assert not conf.with_name("theme.conf.alpnew").exists()


def test_upgrade_core_preserves_modified_config_as_alpnew(paths: alp.Paths, tmp_path: Path):
    old = _install_core_v1_with_config(paths, tmp_path)
    conf = paths.root / "usr/share/themes/alpbah/theme.conf"
    conf.write_bytes(b"dark=true\naccent=orange\n")  # user edited it

    new_archive = _make_tar(tmp_path, "theme-2.0.0.tar.gz", {
        "usr/share/themes/alpbah/theme.conf": b"dark=false\n",
        "usr/share/themes/alpbah/README": b"static, never changes\n",
    })
    entry = {
        "name": "theme", "version": "2.0.0", "url": "theme-2.0.0.tar.gz",
        "sha256": alp.sha256_of(new_archive),
        "config_files": ["/usr/share/themes/alpbah/theme.conf"],
    }

    new_record = alp.upgrade_core(paths, entry, tmp_path, old, dry_run=False)

    # user's file is completely untouched
    assert conf.read_bytes() == b"dark=true\naccent=orange\n"
    # new version written alongside as .alpnew
    alpnew = conf.with_name("theme.conf.alpnew")
    assert alpnew.read_bytes() == b"dark=false\n"
    # recorded hash is UNCHANGED from the old install-time hash (not the
    # user's current content, not upstream's new content) -- so the file
    # stays "modified" on every future upgrade until the user deals with it
    assert (
        new_record["config_hashes"]["/usr/share/themes/alpbah/theme.conf"]
        == old["config_hashes"]["/usr/share/themes/alpbah/theme.conf"]
    )


def test_upgrade_core_removes_files_dropped_in_new_version(paths: alp.Paths, tmp_path: Path):
    old = _install_core_v1_with_config(paths, tmp_path)
    assert (paths.root / "usr/share/themes/alpbah/README").exists()

    new_archive = _make_tar(tmp_path, "theme-2.0.0.tar.gz", {
        "usr/share/themes/alpbah/theme.conf": b"dark=false\n",
        # README dropped in the new version
    })
    entry = {
        "name": "theme", "version": "2.0.0", "url": "theme-2.0.0.tar.gz",
        "sha256": alp.sha256_of(new_archive),
        "config_files": ["/usr/share/themes/alpbah/theme.conf"],
    }

    alp.upgrade_core(paths, entry, tmp_path, old, dry_run=False)

    assert not (paths.root / "usr/share/themes/alpbah/README").exists()
    assert (paths.root / "usr/share/themes/alpbah/theme.conf").exists()


def test_upgrade_dry_run_never_calls_fetch(paths: alp.Paths, tmp_path: Path):
    old = {"version": "1.0.0", "method": "core", "files": [], "config_hashes": {}}
    entry = {"name": "theme", "version": "2.0.0", "url": "theme.tar.gz", "sha256": "0" * 64}
    with mock.patch.object(alp, "fetch") as fetch_mock:
        record = alp.upgrade_core(paths, entry, tmp_path, old, dry_run=True)
    fetch_mock.assert_not_called()
    assert record["status"] == "would-upgrade"


# --------------------------------------------------------------------------
# remove_package -- .alpsave for modified config files
# --------------------------------------------------------------------------

def test_remove_unmodified_config_deletes_normally(paths: alp.Paths, tmp_path: Path):
    record = _install_core_v1_with_config(paths, tmp_path)
    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {"theme": record}}

    alp.remove_package(paths, db, "theme", dry_run=False)

    assert not (paths.root / "usr/share/themes/alpbah").exists()


def test_remove_modified_config_creates_alpsave(paths: alp.Paths, tmp_path: Path):
    record = _install_core_v1_with_config(paths, tmp_path)
    conf = paths.root / "usr/share/themes/alpbah/theme.conf"
    conf.write_bytes(b"dark=true\naccent=orange\n")  # user edited it
    db = {"schema_version": alp.SCHEMA_VERSION, "updated_at": None, "packages": {"theme": record}}

    alp.remove_package(paths, db, "theme", dry_run=False)

    saved = conf.with_name("theme.conf.alpsave")
    assert saved.read_bytes() == b"dark=true\naccent=orange\n"
    assert not conf.exists()  # original path gone, content preserved under .alpsave
    assert not (paths.root / "usr/share/themes/alpbah/README").exists()  # non-config file removed normally


# --------------------------------------------------------------------------
# cmd_upgrade -- CLI-level dispatch
# --------------------------------------------------------------------------

def test_cmd_upgrade_rejects_not_installed(paths: alp.Paths, tmp_path: Path):
    import argparse
    args = argparse.Namespace(name="ghost", dry_run=False)
    index, index_dir = _index(tmp_path, {})
    with pytest.raises(alp.AlpError, match="Kurulu değil"):
        alp.cmd_upgrade(args, paths, index, index_dir)


def test_cmd_upgrade_rejects_flatpak_method(paths: alp.Paths, tmp_path: Path):
    import argparse
    db = alp.load_db(paths)
    db["packages"]["firefox"] = {"version": "130.0", "method": "flatpak", "flatpak_ref": "org.mozilla.firefox"}
    alp.save_db(paths, db)

    args = argparse.Namespace(name="firefox", dry_run=False)
    index, index_dir = _index(tmp_path, {"firefox": {"method": "flatpak", "flatpak_ref": "org.mozilla.firefox", "version": "131.0"}})
    with pytest.raises(alp.AlpError, match="flatpak kendi güncellemesini yönetir"):
        alp.cmd_upgrade(args, paths, index, index_dir)


def test_cmd_upgrade_end_to_end_updates_db(paths: alp.Paths, tmp_path: Path):
    import argparse
    old_archive = _make_tar(tmp_path, "theme-1.0.0.tar.gz", {"usr/share/x": b"old"})
    args = argparse.Namespace(name="theme", dry_run=False, reinstall=False)
    index, index_dir = _index(tmp_path, {
        "theme": {"method": "core", "name": "theme", "version": "1.0.0", "url": "theme-1.0.0.tar.gz", "sha256": alp.sha256_of(old_archive)}
    })
    alp.cmd_install(args, paths, index, index_dir)

    new_archive = _make_tar(tmp_path, "theme-2.0.0.tar.gz", {"usr/share/x": b"new"})
    index2, index_dir2 = _index(tmp_path, {
        "theme": {"method": "core", "name": "theme", "version": "2.0.0", "url": "theme-2.0.0.tar.gz", "sha256": alp.sha256_of(new_archive)}
    })
    upgrade_args = argparse.Namespace(name="theme", dry_run=False)
    assert alp.cmd_upgrade(upgrade_args, paths, index2, index_dir2) == 0

    db = alp.load_db(paths)
    assert db["packages"]["theme"]["version"] == "2.0.0"
    assert (paths.root / "usr/share/x").read_bytes() == b"new"


# --------------------------------------------------------------------------
# _tool_available -- regression test for the real-Linux bug found via SSH
# testing on the alpbah-builder VM: shutil.which("./configure") resolves
# relative to the *interpreter's* cwd (wherever alp.py was invoked from),
# not the build directory (cwd=src_dir) the step actually runs in. A real,
# executable ./configure was reported "not found" purely because of this
# mismatch -- confirmed and fixed against genuine htop 3.3.0 source on
# Ubuntu 24.04 (configure got as far as its real ncursesw dependency check,
# proving the fetch/checksum/extract/invoke pipeline is correct end to end).
# --------------------------------------------------------------------------

def test_tool_available_resolves_relative_path_against_given_cwd(tmp_path: Path):
    """Regression test. Does NOT use os.chdir() -- mutating the live
    process cwd inside a test corrupted Windows subprocess handle state for
    later tests in the same pytest run (observed: WinError 6 in unrelated
    subprocess-based tests further down the suite). Instead this asserts
    the essential behavior directly: _tool_available resolves a
    path-relative binary against the `cwd` argument it's given, not
    against whatever directory happens to be the interpreter's cwd --
    which is exactly the mismatch that made a real, executable
    ./configure read as "not found" (see module docstring above)."""
    real_dir = tmp_path / "real_build_dir"
    real_dir.mkdir()
    configure = real_dir / "configure"
    configure.write_text("#!/bin/sh\necho fake configure\n", encoding="utf-8")
    configure.chmod(0o755)

    wrong_dir = tmp_path / "somewhere_else_entirely"
    wrong_dir.mkdir()

    assert alp._tool_available("./configure", real_dir) is True
    assert alp._tool_available("./configure", wrong_dir) is False


def test_tool_available_missing_relative_tool_returns_false(tmp_path: Path):
    assert alp._tool_available("./does-not-exist", tmp_path) is False


def test_tool_available_plain_command_still_searches_path(tmp_path: Path):
    # Unaffected code path: a bare command name (no "/") still goes through
    # the normal PATH search, same as before -- unrelated to the passed cwd.
    assert alp._tool_available("a-command-that-almost-certainly-does-not-exist-xyz", tmp_path) is False


# --------------------------------------------------------------------------
# _copy_entry -- regression test for the real-Linux bug found testing GNU
# units 2.23 on the alpbah-builder VM: its staged tree contains
# intentionally dangling symlinks (admin-supplied data files that don't
# exist yet); shutil.copyfile() dereferences and raises FileNotFoundError.
# skipif guards environments (e.g. an unprivileged Windows shell without
# Developer Mode) where os.symlink() itself needs elevation to create --
# that's a test-environment limitation, not something about the fix.
# --------------------------------------------------------------------------

def _symlinks_supported(tmp_path: Path) -> bool:
    try:
        target = tmp_path / "_symlink_probe_target"
        target.write_text("x", encoding="utf-8")
        link = tmp_path / "_symlink_probe_link"
        os.symlink(target, link)
        link.unlink()
        target.unlink()
        return True
    except (OSError, NotImplementedError):
        return False


def test_copy_entry_preserves_dangling_symlink(tmp_path: Path):
    if not _symlinks_supported(tmp_path):
        pytest.skip("os.symlink() unavailable/unprivileged in this environment")

    src_dir = tmp_path / "src"
    src_dir.mkdir()
    dangling_link = src_dir / "currency.units"
    os.symlink("/usr/com/units/currency.units", dangling_link)  # target never created -- intentionally dangling

    dst_dir = tmp_path / "dst"
    dst_dir.mkdir()
    dst = dst_dir / "currency.units"

    alp._copy_entry(dangling_link, dst)  # must not raise FileNotFoundError

    assert dst.is_symlink()
    assert os.readlink(dst) == "/usr/com/units/currency.units"


def test_merge_destdir_handles_dangling_symlinks_in_staged_tree(paths: alp.Paths, tmp_path: Path):
    if not _symlinks_supported(tmp_path):
        pytest.skip("os.symlink() unavailable/unprivileged in this environment")

    destdir = tmp_path / "destdir"
    (destdir / "usr/share/units").mkdir(parents=True)
    (destdir / "usr/share/units/definitions.units").write_bytes(b"real content\n")
    os.symlink("/usr/com/units/currency.units", destdir / "usr/share/units/currency.units")

    installed = alp._merge_destdir(destdir, paths.root, dry_run=False)

    assert "/usr/share/units/currency.units" in installed
    link = paths.root / "usr/share/units/currency.units"
    assert link.is_symlink()
    assert os.readlink(link) == "/usr/com/units/currency.units"
    assert (paths.root / "usr/share/units/definitions.units").read_bytes() == b"real content\n"
