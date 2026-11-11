"""ALP-TRUST-01: root-side checks of a staged tree before the merge
(design/trust-model.md section 6.2). These need no root; the device-node
and ownership cases that do are in test_trust_sandbox.py.
"""

from __future__ import annotations

import os
import stat
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

pytestmark = pytest.mark.skipif(os.name != "posix", reason="POSIX dosya izinleri gerekir")


@pytest.fixture
def stage(tmp_path: Path) -> Path:
    s = tmp_path / "stage"
    (s / "usr/bin").mkdir(parents=True)
    (s / "usr/bin/tool").write_text("#!/bin/sh\n")
    (s / "usr/bin/tool").chmod(0o755)
    return s


@pytest.fixture
def root(tmp_path: Path) -> Path:
    r = tmp_path / "root"
    r.mkdir()
    return r


def _merge(stage: Path, root: Path, **kw) -> alp.MergeResult:
    return alp._merge_staged(stage, root, config_files=set(), old_record=None, other_owners={}, **kw)


def _refused(stage: Path, root: Path, needle: str, **kw) -> None:
    with pytest.raises(alp.AlpError, match="reddedildi") as excinfo:
        _merge(stage, root, **kw)
    assert needle in str(excinfo.value)
    assert list(root.iterdir()) == []  # nothing was merged, not even the good files


def test_a_plain_tree_merges(stage, root):
    merged = _merge(stage, root)
    assert "/usr/bin/tool" in merged.installed and (root / "usr/bin/tool").is_file()


@pytest.mark.parametrize("bits", [stat.S_ISUID, stat.S_ISGID, stat.S_ISUID | stat.S_ISGID])
def test_setuid_or_setgid_file_not_listed_in_the_recipe_is_refused(stage, root, bits):
    (stage / "usr/bin/tool").chmod(0o755 | bits)
    _refused(stage, root, "/usr/bin/tool: setuid/setgid")


def test_setuid_file_listed_in_the_recipe_is_merged_with_the_bit(stage, root):
    (stage / "usr/bin/tool").chmod(0o4755)
    allowed = alp._recipe_setuid({"name": "x", "setuid": ["/usr/bin/tool"]})
    _merge(stage, root, setuid_allowed=allowed)
    assert stat.S_IMODE((root / "usr/bin/tool").stat().st_mode) == 0o4755


def test_listing_one_setuid_file_does_not_cover_another(stage, root):
    (stage / "usr/bin/tool").chmod(0o4755)
    (stage / "usr/bin/other").write_text("x")
    (stage / "usr/bin/other").chmod(0o4755)
    _refused(stage, root, "/usr/bin/other: setuid/setgid", setuid_allowed=frozenset({"/usr/bin/tool"}))


def test_setgid_directory_is_refused_unless_listed(stage, root):
    (stage / "var/games").mkdir(parents=True)
    (stage / "var/games").chmod(0o2775)
    _refused(stage, root, "/var/games: setuid/setgid")
    _merge(stage, root, setuid_allowed=frozenset({"/var/games"}))


@pytest.mark.parametrize("bad", [{"setuid": "/usr/bin/su"}, {"setuid": ["usr/bin/su"]}, {"setuid": [1]}])
def test_recipe_setuid_list_must_be_absolute_paths(bad):
    with pytest.raises(alp.AlpError, match="setuid"):
        alp._recipe_setuid({"name": "x", **bad})


def test_core_and_default_merges_allow_no_setuid_at_all():
    assert alp._recipe_setuid({"name": "x"}) == frozenset()
    assert alp._merge_staged.__kwdefaults__["setuid_allowed"] == frozenset()


def test_fifo_is_refused(stage, root):
    os.mkfifo(stage / "usr/bin/pipe")
    with pytest.raises(alp.AlpError, match="FIFO/soket/aygıt"):
        _merge(stage, root)
    assert list(root.iterdir()) == []


def test_socket_is_refused(stage, root):
    import socket
    s = socket.socket(socket.AF_UNIX)
    try:
        s.bind(str(stage / "usr/bin/sock"))
        with pytest.raises(alp.AlpError, match="FIFO/soket/aygıt"):
            _merge(stage, root)
    finally:
        s.close()
    assert list(root.iterdir()) == []


@pytest.mark.parametrize("rel, target", [
    ("usr/bin/escape", "../../../etc/passwd"),
    ("usr/escape", "../../x"),
    ("etc/escape", "a/../../../x"),
])
def test_symlink_that_climbs_out_of_the_root_is_refused(stage, root, rel, target):
    (stage / rel).parent.mkdir(parents=True, exist_ok=True)
    os.symlink(target, stage / rel)
    _refused(stage, root, f"/{rel}: kök dizinin dışını gösteren symlink")


@pytest.mark.parametrize("target", ["tool", "../bin/tool", "../../usr/bin/tool", "/usr/bin/tool", "/etc/alternatives/x",
                                    "../../does/not/exist"])
def test_symlinks_that_stay_inside_are_kept(stage, root, target):
    os.symlink(target, stage / "usr/bin/link")
    _merge(stage, root)
    assert os.readlink(root / "usr/bin/link") == target


def test_relocated_package_may_not_link_to_an_absolute_path_outside_its_root(stage, root):
    os.symlink("/etc/passwd", stage / "usr/bin/link")
    _refused(stage, root, "/usr/bin/link: kök dizinin dışını gösteren symlink", absolute_link_root=root)
    (stage / "usr/bin/link").unlink()
    os.symlink(f"{root}/usr/bin/tool", stage / "usr/bin/link")
    _merge(stage, root, absolute_link_root=root)


@pytest.mark.parametrize("rel", ["tmp/x", "home/user/.bashrc", "root/.ssh/authorized_keys", "dev/x", "run/x",
                                 "proc/x", "sys/x", "mnt/x", "stray", "var/lib/alp/db.json",
                                 "var/lib/alp/rollback/x/journal.jsonl", "var/log/alp/x.log"])
def test_entries_outside_the_allowed_prefixes_are_refused(stage, root, rel):
    (stage / rel).parent.mkdir(parents=True, exist_ok=True)
    (stage / rel).write_text("x")
    with pytest.raises(alp.AlpError, match="reddedildi") as excinfo:
        _merge(stage, root)
    assert "dışında" in str(excinfo.value) or "durum/günlük" in str(excinfo.value)
    assert list(root.iterdir()) == []


@pytest.mark.parametrize("rel", ["usr/share/x", "etc/x.conf", "var/lib/x/state", "opt/x/bin/x", "boot/x",
                                 "lib/udev/rules.d/x.rules", "srv/x"])
def test_entries_inside_the_allowed_prefixes_merge(stage, root, rel):
    (stage / rel).parent.mkdir(parents=True, exist_ok=True)
    (stage / rel).write_text("x")
    _merge(stage, root)
    assert (root / rel).is_file()


def test_hard_link_to_a_file_outside_the_stage_is_refused_and_the_file_is_untouched(stage, root, tmp_path):
    outside = tmp_path / "outside-secret"
    outside.write_text("secret")
    outside.chmod(0o666)
    os.link(outside, stage / "usr/bin/leak")
    _refused(stage, root, "/usr/bin/leak: hazırlık dizininin dışına sabit bağ")
    assert stat.S_IMODE(outside.stat().st_mode) == 0o666  # not chmod-ed through the link
    assert outside.read_text() == "secret"


def test_hard_links_inside_the_stage_are_fine(stage, root):
    os.link(stage / "usr/bin/tool", stage / "usr/bin/tool-alias")
    _merge(stage, root)
    assert (root / "usr/bin/tool-alias").read_text() == (root / "usr/bin/tool").read_text()


def test_group_and_other_write_is_dropped_everywhere_except_sticky_directories(stage, root):
    (stage / "usr/bin/tool").chmod(0o777)
    loose_dirs = ["usr/share/loose", "etc/loose.d", "var/lib/loose", "opt/loose", "boot/loose"]
    loose_files = ["etc/x.conf", "var/lib/loose/state", "opt/loose/data", "boot/loose/cfg"]
    for rel in loose_dirs:
        (stage / rel).mkdir(parents=True)
    for rel in loose_files:
        (stage / rel).write_text("x")
        (stage / rel).chmod(0o666)
    for rel in loose_dirs:
        (stage / rel).chmod(0o777)
    (stage / "var/spool/x").mkdir(parents=True)
    (stage / "var/spool/x").chmod(0o1777)
    (stage / "var/spool/x/inside").write_text("x")
    (stage / "var/spool/x/inside").chmod(0o666)
    (stage / "etc/keep").write_text("x")
    (stage / "etc/keep").chmod(0o640)
    _merge(stage, root)
    mode = lambda rel: stat.S_IMODE((root / rel).stat().st_mode)  # noqa: E731
    assert mode("usr/bin/tool") == 0o755
    assert [mode(rel) for rel in loose_dirs] == [0o755] * len(loose_dirs)
    assert [mode(rel) for rel in loose_files] == [0o644] * len(loose_files)
    assert mode("var/spool/x") == 0o1777  # sticky directory: world-writable on purpose, kept
    assert mode("var/spool/x/inside") == 0o644  # a file inside it is not
    assert mode("etc/keep") == 0o640  # other bits are not touched


def test_sticky_bit_on_a_file_does_not_keep_it_writable(stage, root):
    (stage / "usr/bin/tool").chmod(0o1777)
    _merge(stage, root)
    assert stat.S_IMODE((root / "usr/bin/tool").stat().st_mode) & 0o022 == 0


def test_normalising_does_not_follow_a_symlink(stage, root, tmp_path):
    outside = tmp_path / "outside"
    outside.write_text("x")
    outside.chmod(0o666)
    os.symlink(str(outside), stage / "usr/bin/abs")  # absolute target: allowed for a package built for "/"
    _merge(stage, root)
    assert stat.S_IMODE(outside.stat().st_mode) == 0o666


def test_every_problem_is_reported_at_once(stage, root):
    (stage / "usr/bin/tool").chmod(0o4755)
    os.symlink("../../../x", stage / "usr/bin/escape")
    (stage / "tmp").mkdir()
    (stage / "tmp/x").write_text("x")
    with pytest.raises(alp.AlpError) as excinfo:
        _merge(stage, root)
    text = str(excinfo.value)
    assert "setuid/setgid" in text and "symlink" in text and "/tmp/x" in text
