"""Rollback when an upgrade turns a package-owned file or symlink into a directory.

Found in the 29 Sep 2026 audit (handoff 020): `FileJournal._seen` dropped the
`will_mkdir` record that follows `will_remove` of the same path, so undo never
removed the new directory. `os.replace(backup, <directory>)` then failed and the
`shutil.copy2` fallback copied the backup *into* the directory and reported
success: the transaction said "geri alındı" while /usr/x stayed a directory
holding a file named "1" (file case), or failed loudly (symlink case).
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import alp  # noqa: E402

pytestmark = pytest.mark.skipif(os.name != "posix", reason="symlinks and modes need POSIX")


def _setup(tmp_path: Path, old_kind: str):
    root = tmp_path / "root"
    (root / "usr").mkdir(parents=True)
    staged = tmp_path / "stage"
    (staged / "usr" / "x").mkdir(parents=True)
    (staged / "usr" / "x" / "y").write_text("new", encoding="utf-8")
    if old_kind == "file":
        (root / "usr" / "x").write_text("old-file", encoding="utf-8")
    else:
        (root / "usr" / "target").mkdir()
        os.symlink("target", root / "usr" / "x")
    paths = alp.Paths.resolve(str(root))
    paths.ensure()
    old_record = {"files": ["/usr/x"], "symlinks": ["/usr/x"] if old_kind == "symlink" else []}
    return paths, root, staged, old_record


def _merge_then_fail(paths, root, staged, old_record):
    with pytest.raises(RuntimeError, match="boom"):
        with alp._transaction(paths, "t") as journal:
            alp._merge_staged(
                staged, root, config_files=set(), old_record=old_record, other_owners={}, journal=journal,
            )
            raise RuntimeError("boom")


def test_file_that_becomes_a_directory_is_restored(tmp_path):
    paths, root, staged, old_record = _setup(tmp_path, "file")
    _merge_then_fail(paths, root, staged, old_record)
    x = root / "usr" / "x"
    assert x.is_file() and not x.is_symlink(), "the original file must be back, not a directory"
    assert x.read_text(encoding="utf-8") == "old-file"
    assert sorted(p.name for p in (root / "usr").iterdir()) == ["x"]
    assert alp.pending_journals(paths) == []


def test_symlink_that_becomes_a_directory_is_restored(tmp_path):
    paths, root, staged, old_record = _setup(tmp_path, "symlink")
    _merge_then_fail(paths, root, staged, old_record)
    x = root / "usr" / "x"
    assert x.is_symlink() and os.readlink(x) == "target"
    assert (root / "usr" / "target").is_dir()
    assert alp.pending_journals(paths) == [], "a fully restored transaction must not leave its journal behind"


def test_undo_never_copies_a_backup_into_a_directory(tmp_path):
    """If something else now occupies the path with a non-empty directory, undo
    must report the failure and keep the backup instead of nesting it."""
    root = tmp_path / "root"
    (root / "usr").mkdir(parents=True)
    victim = root / "usr" / "x"
    victim.write_text("old-file", encoding="utf-8")
    journal = alp.FileJournal(tmp_path / "journal")
    journal.will_remove(victim)
    victim.unlink()
    victim.mkdir()
    (victim / "foreign").write_text("not ours", encoding="utf-8")
    journal.close()

    failures = alp.undo_journal(journal.log_file)

    assert failures, "restoring over a non-empty directory must be reported"
    assert sorted(p.name for p in victim.iterdir()) == ["foreign"], "backup must not be copied into the directory"
    backups = list((journal.dir / "files").iterdir())
    assert len(backups) == 1 and backups[0].read_text(encoding="utf-8") == "old-file"
