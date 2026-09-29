"""Regression tests for the EXIT-trap cleanup() of scripts/patch-m2-gen2-*.sh.

Every one of these scripts mounts a guest image at "$WORK/root" and removes
"$WORK" in its EXIT trap. When `umount` failed ("target is busy" after an
interrupted run) the old trap ran `rm -rf -- "$WORK"` anyway, which walks into
the still-mounted guest filesystem and deletes its contents. The trap must
instead keep everything and exit non-zero, like build-m2-gen2-test-image.sh.

The tests run only the extracted cleanup() function under bash with stub
`umount`/`qemu-nbd` binaries; nothing is mounted and no real device is touched.
"""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import unittest
from pathlib import Path

SCRIPTS = sorted((Path(__file__).resolve().parents[1] / "scripts").glob("patch-m2-gen2-*.sh"))
BASH = shutil.which("bash")


def _cleanup_source(script: Path) -> str:
    lines = script.read_text(encoding="utf-8").splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("cleanup()"))
    first = lines[start].strip()
    if first != "cleanup() {" and first.endswith("}"):
        return lines[start]  # legacy one-line definition
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == "}")
    return "\n".join(lines[start:end + 1])


def _run_cleanup(script: Path, root: Path, *, umount_ok: bool) -> tuple[subprocess.CompletedProcess, Path, Path, Path]:
    work = root / "work"
    mount = work / "root"
    (mount / "boot" / "efi").mkdir(parents=True)
    sentinel = mount / "etc" / "shadow"
    sentinel.parent.mkdir()
    sentinel.write_text("guest data", encoding="utf-8")
    bin_dir = root / "bin"
    bin_dir.mkdir()
    calls = root / "calls.log"
    umount = bin_dir / "umount"
    umount.write_text(
        f'#!/bin/sh\necho "umount $*" >> {shlex.quote(str(calls))}\n'
        + ("exit 0\n" if umount_ok else 'echo "umount: target is busy" >&2\nexit 32\n'),
        encoding="utf-8",
    )
    qemu_nbd = bin_dir / "qemu-nbd"
    qemu_nbd.write_text(f'#!/bin/sh\necho "qemu-nbd $*" >> {shlex.quote(str(calls))}\nexit 0\n', encoding="utf-8")
    for stub in (umount, qemu_nbd):
        stub.chmod(0o755)
    program = "\n".join([
        "set -Eeuo pipefail",
        f"WORK={shlex.quote(str(work))}",
        'MOUNT="$WORK/root"',
        "NBD=/dev/nbd0",
        "ATTACHED=1; ROOT_MOUNTED=1; MOUNTED=1; EFI_MOUNTED=1",
        _cleanup_source(script),
        "cleanup",
    ])
    env = {**os.environ, "PATH": f"{bin_dir}{os.pathsep}{os.environ.get('PATH', '')}"}
    proc = subprocess.run([BASH, "-c", program], env=env, capture_output=True, text=True, check=False)
    return proc, work, sentinel, calls


@unittest.skipUnless(BASH and os.name == "posix", "requires bash on a POSIX host")
class PatchScriptCleanupTests(unittest.TestCase):
    def test_scripts_are_discovered(self):
        self.assertGreaterEqual(len(SCRIPTS), 6)

    def test_scripts_parse(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                proc = subprocess.run([BASH, "-n", str(script)], capture_output=True, text=True, check=False)
                self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_failed_umount_preserves_the_mounted_tree(self):
        import tempfile

        for script in SCRIPTS:
            with self.subTest(script=script.name), tempfile.TemporaryDirectory() as tmp:
                proc, work, sentinel, calls = _run_cleanup(script, Path(tmp), umount_ok=False)
                self.assertTrue(sentinel.exists(), f"cleanup deleted guest files after a failed umount\n{proc.stderr}")
                self.assertTrue(work.exists())
                self.assertEqual(proc.returncode, 1, proc.stderr)
                self.assertIn("CLEANUP FAILED", proc.stderr)
                log = calls.read_text(encoding="utf-8") if calls.exists() else ""
                self.assertNotIn("--disconnect", log, "device must not be detached while its filesystem is still mounted")

    def test_clean_run_removes_work_dir_and_detaches(self):
        import tempfile

        for script in SCRIPTS:
            with self.subTest(script=script.name), tempfile.TemporaryDirectory() as tmp:
                proc, work, _sentinel, calls = _run_cleanup(script, Path(tmp), umount_ok=True)
                self.assertEqual(proc.returncode, 0, proc.stderr)
                self.assertFalse(work.exists())
                self.assertIn("--disconnect", calls.read_text(encoding="utf-8"))

    def test_rm_never_crosses_filesystems(self):
        for script in SCRIPTS:
            with self.subTest(script=script.name):
                self.assertIn("rm -rf --one-file-system -- ", _cleanup_source(script))


if __name__ == "__main__":
    unittest.main()
