"""Tests for scripts/rebuild/r4/r4_lib.py and make_packages_tsv.py.

Run: python3 -m unittest tests.test_r4_driver   (from the repo root)
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
R4 = os.path.join(HERE, "..", "scripts", "rebuild", "r4")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


lib = load("r4_lib", os.path.join(R4, "r4_lib.py"))
mk = load("make_packages_tsv", os.path.join(R4, "make_packages_tsv.py"))
LIB_PY = os.path.join(R4, "r4_lib.py")


class SplitTests(unittest.TestCase):
    def test_split(self):
        self.assertEqual(lib.split_name_version("libtasn1-4.20.0"), ("libtasn1", "4.20.0"))
        self.assertEqual(lib.split_name_version("docbook-xsl-nons-1.79.2"), ("docbook-xsl-nons", "1.79.2"))
        self.assertEqual(lib.split_name_version("pcre2-10.45"), ("pcre2", "10.45"))
        self.assertEqual(lib.split_name_version("icu4c-78.3-sources"), ("icu4c", "78.3"))
        self.assertEqual(lib.split_name_version("openldap-LMDB_1.0.1"), ("openldap", "LMDB_1.0.1"))
        self.assertEqual(lib.split_name_version("Linux-PAM-1.7.2"), ("Linux-PAM", "1.7.2"))
        with self.assertRaises(ValueError):
            lib.split_name_version("nodigits")


class Md5Tests(unittest.TestCase):
    def test_md5_match_and_mismatch(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "x.tar")
            with open(p, "wb") as f:
                f.write(b"abc")
            self.assertEqual(lib.md5_of(p), "900150983cd24fb0d6963f7d28e17f72")
            ok = subprocess.call([sys.executable, LIB_PY, "md5", p, "900150983cd24fb0d6963f7d28e17f72"],
                                 stdout=subprocess.DEVNULL)
            bad = subprocess.call([sys.executable, LIB_PY, "md5", p, "00"], stdout=subprocess.DEVNULL)
            self.assertEqual((ok, bad), (0, 1))


class ManifestTests(unittest.TestCase):
    def test_manifest_keeps_changed_files_and_symlinks_only(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "usr/lib"))
            os.makedirs(os.path.join(root, "sources"))
            with open(os.path.join(root, "usr/lib/libfoo.so.1"), "wb") as f:
                f.write(b"\x7fELFxx")
            os.symlink("libfoo.so.1", os.path.join(root, "usr/lib/libfoo.so"))
            with open(os.path.join(root, "sources/junk"), "w") as f:
                f.write("x")
            diff = os.path.join(root, "diff.tsv")
            with open(diff, "w") as f:
                f.write("A\tusr/lib/libfoo.so.1\tfile\t755\t0\t0\t6\t\n")
                f.write("A\tusr/lib/libfoo.so\tsymlink\t777\t0\t0\t0\tlibfoo.so.1\n")
                f.write("A\tsources/junk\tfile\t644\t0\t0\t1\t\n")
                f.write("D\tusr/old\tfile\t644\t0\t0\t1\t\n")
            out = os.path.join(root, "m.json")
            rc = subprocess.call([sys.executable, LIB_PY, "manifest", "--root", root, "--diff", diff,
                                  "--name", "libfoo", "--version", "1.0", "--url", "https://x/libfoo-1.0.tar.gz",
                                  "--sha256", "ab" * 32, "--out", out],
                                 stdout=subprocess.DEVNULL)
            self.assertEqual(rc, 0)
            doc = json.load(open(out))
            self.assertEqual(doc["package"]["name"], "libfoo")
            self.assertEqual(doc["schema"], "alpbahOS.package-files/v1")
            paths = {e["path"]: e for e in doc["entries"]}
            self.assertEqual(sorted(paths), ["/usr/lib/libfoo.so", "/usr/lib/libfoo.so.1"])
            self.assertEqual(paths["/usr/lib/libfoo.so"]["target"], "libfoo.so.1")
            self.assertEqual(paths["/usr/lib/libfoo.so.1"]["mode"], 0o755)
            self.assertEqual(paths["/usr/lib/libfoo.so.1"]["size"], 6)

    def test_elfs_filter(self):
        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "usr/bin"))
            with open(os.path.join(root, "usr/bin/tool"), "wb") as f:
                f.write(b"\x7fELF\x02")
            with open(os.path.join(root, "usr/bin/script"), "w") as f:
                f.write("#!/bin/sh\n")
            diff = os.path.join(root, "diff.tsv")
            with open(diff, "w") as f:
                f.write("A\tusr/bin/tool\tfile\t755\t0\t0\t5\t\n")
                f.write("A\tusr/bin/script\tfile\t755\t0\t0\t9\t\n")
            out = subprocess.run([sys.executable, LIB_PY, "elfs", "--root", root, "--diff", diff],
                                 capture_output=True, text=True).stdout.split()
            self.assertEqual(out, [os.path.join(root, "usr/bin/tool")])


class PlanTests(unittest.TestCase):
    def test_build_marks_missing_sources_and_notes(self):
        with tempfile.TemporaryDirectory() as repo, tempfile.TemporaryDirectory() as src:
            os.makedirs(os.path.join(repo, "scripts/lfs-blfs/src-meta"))
            with open(os.path.join(repo, "scripts/lfs-blfs/order.txt"), "w") as f:
                f.write("001 which-2.23 REQ https://x/which.html\n002 libtasn1-4.20.0 REQ https://x/t.html\n")
            with open(os.path.join(repo, "scripts/lfs-blfs/src-meta/packages.tsv"), "w") as f:
                f.write("NN\tname-version\ttarball\turl\tmd5\tnotes\tpage\n")
                f.write("001\twhich-2.23\twhich-2.23.tar.gz\thttps://x/w.tgz\tabc\t\thttps://x/which.html\n")
                f.write("002\tlibtasn1-4.20.0\tlibtasn1-4.20.0.tar.gz\thttps://x/t.tgz\tdef\t\thttps://x/t.html\n")
            open(os.path.join(src, "which-2.23.tar.gz"), "w").close()
            dev = os.path.join(repo, "dev.md")
            with open(dev, "w") as f:
                f.write("- 002 libtasn1: gtk-doc kapatildi.\n")
            rows = mk.build(repo, dev, src, "")
            self.assertEqual(rows[0][7], "yes")
            self.assertEqual(rows[1][7], "no")
            self.assertIn("gtk-doc", rows[1][9])


if __name__ == "__main__":
    unittest.main()
