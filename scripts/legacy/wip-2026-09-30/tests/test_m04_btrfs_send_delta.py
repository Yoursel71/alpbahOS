"""Opt-in, disposable Btrfs send/receive metadata fidelity probe.

Run only with M04_RUN_BTRFS_DELTA_INTEGRATION=1. The test creates temporary
subvolumes below the user's home, never the active LFS root or D34 candidate.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


ENABLE_FLAG = "M04_RUN_BTRFS_DELTA_INTEGRATION"


def _enabled_skip_reason() -> str | None:
    if os.environ.get(ENABLE_FLAG) != "1":
        return f"set {ENABLE_FLAG}=1 to opt in"
    if shutil.which("btrfs") is None:
        return "btrfs-progs is unavailable"
    if shutil.which("sudo") is None:
        return "sudo is unavailable"
    probe = subprocess.run(["sudo", "-n", "true"], check=False, capture_output=True)
    if probe.returncode:
        return "passwordless sudo is required for disposable subvolume operations"
    return None


@unittest.skipIf(_enabled_skip_reason() is not None, _enabled_skip_reason() or "")
class BtrfsIncrementalSendTests(unittest.TestCase):
    def setUp(self):
        self.parent = Path(tempfile.mkdtemp(prefix="m04-btrfs-send-", dir=Path.home()))
        fs_type = subprocess.run(
            ["findmnt", "-T", str(self.parent), "-n", "-o", "FSTYPE"],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        if fs_type != "btrfs":
            self.fail(f"temporary fixture is on {fs_type}, expected Btrfs")
        self.base = self.parent / "base"
        self.base_ro = self.parent / "base-ro"
        self.layer = self.parent / "layer"
        self.after_ro = self.parent / "after-ro"
        self.received = self.parent / "received"
        self.received.mkdir()
        self.stream = self.parent / "incremental-send.bin"

    def tearDown(self):
        cleanup_errors = []
        for path in (self.received / self.after_ro.name, self.after_ro,
                     self.layer, self.base_ro, self.base):
            if path.exists():
                result = subprocess.run(
                    ["sudo", "-n", "btrfs", "subvolume", "delete", str(path)],
                    check=False, capture_output=True, text=True,
                )
                if result.returncode:
                    cleanup_errors.append(f"{path}: {result.stderr.strip()}")
        shutil.rmtree(self.parent, ignore_errors=True)
        if cleanup_errors or self.parent.exists():
            self.fail(f"disposable Btrfs fixture cleanup failed: {cleanup_errors}; {self.parent}")

    def _run(self, *argv: str):
        return subprocess.run(list(argv), check=True, capture_output=True, text=True)

    def _sudo_btrfs(self, *argv: str):
        return self._run("sudo", "-n", "btrfs", *argv)

    def _manifest(self, root: Path) -> dict:
        entries: dict[str, dict] = {}
        inode_groups: dict[tuple[int, int], list[str]] = {}
        for base, dirs, files in os.walk(root, topdown=True, followlinks=False):
            base_path = Path(base)
            names = sorted(set(dirs) | set(files))
            for name in names:
                path = base_path / name
                rel = "/" + path.relative_to(root).as_posix()
                info = os.lstat(path)
                item = {
                    "mode": stat.S_IMODE(info.st_mode),
                    "uid": info.st_uid,
                    "gid": info.st_gid,
                    "mtime_ns": info.st_mtime_ns,
                }
                try:
                    xattrs = sorted(os.listxattr(path, follow_symlinks=False))
                    item["xattrs"] = {
                        key: os.getxattr(path, key, follow_symlinks=False).hex()
                        for key in xattrs
                        if key.startswith("user.") or key in {
                            "security.capability", "system.posix_acl_access",
                            "system.posix_acl_default",
                        }
                    }
                except OSError as exc:
                    self.fail(f"cannot inspect xattrs for {path}: {exc}")
                if stat.S_ISREG(info.st_mode):
                    item.update(type="file", size=info.st_size)
                    digest = hashlib.sha256()
                    with path.open("rb") as stream:
                        for block in iter(lambda: stream.read(1024 * 1024), b""):
                            digest.update(block)
                    item["sha256"] = digest.hexdigest()
                    if info.st_nlink > 1:
                        inode_groups.setdefault((info.st_dev, info.st_ino), []).append(rel)
                elif stat.S_ISDIR(info.st_mode):
                    item["type"] = "directory"
                elif stat.S_ISLNK(info.st_mode):
                    item.update(type="symlink", target=os.readlink(path))
                elif stat.S_ISFIFO(info.st_mode):
                    item["type"] = "fifo"
                else:
                    item.update(type="special", rdev=info.st_rdev)
                entries[rel] = item
        for paths in inode_groups.values():
            group = sorted(paths)
            for rel in group:
                entries[rel]["hardlink_group"] = group
        return entries

    def test_incremental_send_receive_preserves_install_delta_metadata(self):
        self._sudo_btrfs("subvolume", "create", str(self.base))
        self._run("sudo", "-n", "chmod", "0777", str(self.base))
        (self.base / "etc").mkdir()
        (self.base / "usr/bin").mkdir(parents=True)
        (self.base / "var/cache").mkdir(parents=True)
        (self.base / "etc/config").write_text("before\n", encoding="utf-8")
        (self.base / "var/cache/obsolete").write_text("remove me\n", encoding="utf-8")
        (self.base / "usr/bin/old-name").write_text("rename me\n", encoding="utf-8")
        (self.base / "etc/owner-change").write_text("ownership transition\n", encoding="utf-8")
        (self.base / "usr/bin/link-a").write_text("shared inode\n", encoding="utf-8")
        os.link(self.base / "usr/bin/link-a", self.base / "usr/bin/link-b")
        (self.base / "etc/current").symlink_to("config")
        self._run("sudo", "-n", "chown", "0:0", str(self.base / "etc/owner-change"))

        self._sudo_btrfs("subvolume", "snapshot", "-r", str(self.base), str(self.base_ro))
        self._sudo_btrfs("subvolume", "snapshot", str(self.base_ro), str(self.layer))
        self._run("sudo", "-n", "chown", f"{os.getuid()}:{os.getgid()}", str(self.layer))
        self._run("sudo", "-n", "chown", f"{os.getuid()}:{os.getgid()}",
                  str(self.layer / "etc/owner-change"))

        (self.layer / "etc/config").write_text("after replacement\n", encoding="utf-8")
        (self.layer / "var/cache/obsolete").unlink()
        (self.layer / "usr/bin/old-name").rename(self.layer / "usr/bin/new-name")
        (self.layer / "usr/bin/new-tool").write_text("new payload\n", encoding="utf-8")
        self._run("sudo", "-n", "chown", f"{os.getuid()}:2345", str(self.layer / "usr/bin/new-tool"))
        os.chmod(self.layer / "usr/bin/new-tool", 0o4751)
        os.setxattr(self.layer / "usr/bin/new-tool", "user.alpbahos-d34", b"recorded")
        os.utime(self.layer / "usr/bin/new-tool", ns=(1_700_000_000_000_000_000,
                                                        1_700_000_000_000_000_000))
        (self.layer / "etc/current").unlink()
        (self.layer / "etc/current").symlink_to("../usr/bin/new-tool")
        os.chmod(self.layer / "etc", 0o751)
        os.mkfifo(self.layer / "var/cache/install.fifo", 0o640)

        self._sudo_btrfs("subvolume", "snapshot", "-r", str(self.layer), str(self.after_ro))
        with self.stream.open("wb") as output:
            subprocess.run(["sudo", "-n", "btrfs", "send", "-p",
                            str(self.base_ro), str(self.after_ro)],
                           check=True, stdout=output)
        self._run("sudo", "-n", "btrfs", "receive", "-f", str(self.stream), str(self.received))
        send_dump = self._run("sudo", "-n", "btrfs", "receive", "--dump",
                              "-f", str(self.stream)).stdout
        received_root = self.received / self.after_ro.name
        self.assertTrue(received_root.is_dir(), f"missing received subvolume: {received_root}")

        baseline = self._manifest(self.base_ro)
        expected = self._manifest(self.after_ro)
        actual = self._manifest(received_root)
        self.assertEqual(actual, expected)
        self.assertNotIn("/var/cache/obsolete", actual)
        self.assertEqual(actual["/usr/bin/new-tool"]["uid"], os.getuid())
        self.assertEqual(actual["/usr/bin/new-tool"]["gid"], 2345)
        self.assertEqual(actual["/etc/owner-change"]["uid"], os.getuid())
        self.assertEqual(actual["/usr/bin/new-tool"]["mode"], 0o4751)
        self.assertEqual(actual["/etc/current"]["target"], "../usr/bin/new-tool")
        self.assertEqual(actual["/var/cache/install.fifo"]["type"], "fifo")
        self.assertEqual(actual["/usr/bin/link-a"]["hardlink_group"],
                         ["/usr/bin/link-a", "/usr/bin/link-b"])
        for path in ("new-tool", "obsolete", "current", "owner-change", "install.fifo"):
            self.assertIn(path, send_dump)
        result = {
            "result": "PASS",
            "changed_paths": sum(baseline.get(path) != expected.get(path)
                                 for path in set(baseline) | set(expected)),
            "stream_bytes": self.stream.stat().st_size,
            "stream_dump": send_dump.splitlines(),
            "subvolume_filesystem": "btrfs",
            "metadata_checked": ["mode", "uid", "gid", "mtime", "user xattrs",
                                 "content", "symlink", "hardlink", "fifo", "deletion"],
        }
        artifact_root = os.environ.get("M04_BTRFS_DELTA_ARTIFACT_DIR")
        if artifact_root:
            destination = Path(artifact_root).resolve()
            if destination == self.parent or self.parent in destination.parents:
                self.fail("durable probe artifacts must stay outside disposable Btrfs fixtures")
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copy2(self.stream, destination / "incremental-send.bin")
            (destination / "receive-dump.txt").write_text(send_dump, encoding="utf-8")
            (destination / "summary.json").write_text(
                json.dumps({key: value for key, value in result.items() if key != "stream_dump"},
                           indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    unittest.main()
