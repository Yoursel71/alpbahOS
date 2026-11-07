"""Tests for scripts/rebuild/r3/r3_ledger.py (REBUILD-R3): step diff, last-writer owners, tarball names."""
import io
import os
import sys
import contextlib
import pathlib
import subprocess
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parents[1] / "scripts" / "rebuild" / "r3"
sys.path.insert(0, str(HERE))
import r3_ledger as L  # noqa: E402


def write(root, rel, data=b"x"):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as f:
        f.write(data)
    return p


class DiffTests(unittest.TestCase):
    def test_add_change_delete_and_excluded_trees(self):
        with tempfile.TemporaryDirectory() as pre, tempfile.TemporaryDirectory() as cur:
            write(pre, "usr/bin/keep", b"same")
            write(pre, "usr/lib/old", b"gone")
            write(pre, "usr/lib/chg", b"v1")
            write(pre, "sources/tar.xz", b"big")
            os.makedirs(os.path.join(cur, "usr", "bin"), exist_ok=True)
            # A hard link keeps the inode and ctime, as a btrfs snapshot does for untouched files.
            os.link(os.path.join(pre, "usr/bin/keep"), os.path.join(cur, "usr/bin/keep"))
            write(cur, "usr/lib/chg", b"v2-longer")
            write(cur, "usr/bin/new", b"n")
            write(cur, "sources/tar.xz", b"big2")  # excluded tree: never reported
            rows = self._diff(pre, cur)
            ops = {r[1]: r[0] for r in rows}
            self.assertEqual(ops.get("usr/bin/new"), "A")
            self.assertEqual(ops.get("usr/lib/chg"), "C")
            self.assertEqual(ops.get("usr/lib/old"), "D")
            self.assertNotIn("sources/tar.xz", ops)
            self.assertNotIn("usr/bin/keep", ops)

    def test_symlink_target_change_is_reported(self):
        if not hasattr(os, "symlink"):
            self.skipTest("no symlinks")
        with tempfile.TemporaryDirectory() as pre, tempfile.TemporaryDirectory() as cur:
            for root, target in ((pre, "a"), (cur, "b")):
                os.makedirs(os.path.join(root, "usr"), exist_ok=True)
                try:
                    os.symlink(target, os.path.join(root, "usr", "ln"))
                except OSError:
                    self.skipTest("cannot create symlinks here")
            rows = self._diff(pre, cur)
            self.assertEqual([(r[0], r[1], r[2], r[7]) for r in rows], [("C", "usr/ln", "symlink", "b")])

    def _diff(self, pre, cur):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            L.cmd_diff(pre, cur)
        return [line.split("\t") for line in buf.getvalue().splitlines() if line]


class OwnersTests(unittest.TestCase):
    def test_last_writer_owns_and_delete_releases(self):
        with tempfile.TemporaryDirectory() as d:
            steps = os.path.join(d, "steps")
            os.makedirs(steps)
            with open(os.path.join(steps, "ch08-01.tsv"), "w") as f:
                f.write("A\tusr/lib/a\tfile\t644\t0\t0\t1\t\nA\tusr/lib/b\tfile\t644\t0\t0\t1\t\n")
            with open(os.path.join(steps, "ch08-02.tsv"), "w") as f:
                f.write("C\tusr/lib/a\tfile\t644\t0\t0\t2\t\nD\tusr/lib/b\tfile\t644\t0\t0\t1\t\n")
            with open(os.path.join(steps, "zz-alp.tsv"), "w") as f:
                f.write("A\tusr/bin/alp\tfile\t755\t0\t0\t9\t\n")
            owners = os.path.join(d, "owners.tsv")
            conf = os.path.join(d, "conf.tsv")
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                L.cmd_owners(steps, owners, conf)
            self.assertIn("owned paths: 2", buf.getvalue())
            self.assertIn("written by more than one step: 1", buf.getvalue())
            with open(owners, encoding="utf-8") as f:
                got = dict(line.split("\t") for line in f.read().splitlines())
            self.assertEqual(got, {"usr/lib/a": "ch08-02", "usr/bin/alp": "zz-alp"})
            with open(conf, encoding="utf-8") as f:
                conflicts = f.read().splitlines()
            self.assertEqual(conflicts[1], "usr/lib/a\tch08-02\tch08-01,ch08-02")


class PackageNameTests(unittest.TestCase):
    def test_tarball_names(self):
        cases = {
            "glibc-2.44.tar.xz": ("glibc", "2.44"),
            "dracut-ng-112.tar.gz": ("dracut-ng", "112"),
            "gcc-16.2.0.tar.xz": ("gcc", "16.2.0"),
            "linux-7.1.8.tar.xz": ("linux", "7.1.8"),
        }
        for tar, (name, ver) in cases.items():
            m = L.TAR_RE.match(tar)
            self.assertIsNotNone(m, tar)
            self.assertEqual((m.group("name"), m.group("ver")), (name, ver), tar)

    def test_no_version_in_name_does_not_match(self):
        self.assertIsNone(L.TAR_RE.match("tcl8.6.16-src.tar.gz"))


if __name__ == "__main__":
    unittest.main()
