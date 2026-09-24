"""Opt-in Linux integration probe for M04 Bubblewrap/seccomp confinement.

This test is intentionally skipped on ordinary developer/CI runs. It creates
and destroys only a marked temporary fixture; it never touches /mnt/lfs.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import platform
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


CAPTURE_SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "capture-m04-install-event.py"
SPEC = importlib.util.spec_from_file_location("m04_linux_integration_capture", CAPTURE_SCRIPT)
capture = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(capture)

ENABLE_FLAG = "M04_RUN_LINUX_SECCOMP_INTEGRATION"


def _integration_skip_reason() -> str | None:
    if os.environ.get(ENABLE_FLAG) != "1":
        return f"set {ENABLE_FLAG}=1 to opt in"
    if sys.platform != "linux":
        return "requires Linux"
    if platform.machine().lower() not in {"x86_64", "amd64", "aarch64", "arm64"}:
        return f"unsupported seccomp architecture: {platform.machine()}"
    missing = [name for name in ("bwrap", "strace") if not shutil.which(name)]
    if missing:
        return "missing required tools: " + ", ".join(missing)
    return None


@unittest.skipIf(_integration_skip_reason() is not None, _integration_skip_reason() or "")
class LinuxSeccompIntegrationTests(unittest.TestCase):
    def test_fixture_install_and_io_uring_eperm_deny_are_persisted(self):
        with tempfile.TemporaryDirectory(prefix="m04-seccomp-integration-") as temp:
            root = Path(temp).resolve()
            (root / capture.MARKER).write_text(capture.MARKER_TEXT, encoding="utf-8")
            (root / "usr/bin").mkdir(parents=True)

            # A regular synthetic install must write only inside the fixture and
            # produce a complete, hash-verifiable successful event.
            install_code = (
                "from pathlib import Path; "
                "Path('usr/bin/m04-fixture-installed').write_text('installed\\n')"
            )
            installed = capture.capture_install(
                root, [sys.executable, "-B", "-c", install_code], cwd=root,
                package="m04-seccomp-fixture", version="1",
            )
            installed_event_path = root / installed["event_manifest"]["path"]
            self._assert_persisted_event(root, installed, installed_event_path)
            self.assertEqual(installed["exit_status"], 0)
            self.assertEqual(installed["observation_violations"], [])
            self.assertIn("/usr/bin/m04-fixture-installed", installed["changed_paths"])
            self.assertEqual((root / "usr/bin/m04-fixture-installed").read_text(), "installed\n")

            # The command reports success only when the kernel returns exactly
            # EPERM. The capture runner must still reject and persist this event
            # because the attempted syscall is an observation violation.
            io_uring_code = (
                "import ctypes, errno, json, os; "
                "libc=ctypes.CDLL(None, use_errno=True); "
                "params=ctypes.create_string_buffer(120); "
                "rc=libc.syscall(425, 1, ctypes.byref(params)); "
                "err=ctypes.get_errno() if rc < 0 else 0; "
                "os.close(rc) if rc >= 0 else None; "
                "print(json.dumps({'rc': rc, 'errno': err})); "
                "raise SystemExit(0 if rc == -1 and err == errno.EPERM else 42)"
            )
            prior_event_ids = {path.name for path in (root / capture.CAPTURE_DIR / "events").iterdir()}
            with self.assertRaisesRegex(capture.CaptureError, r"observation violations \(io_uring_setup\)") as caught:
                capture.capture_install(
                    root, [sys.executable, "-B", "-c", io_uring_code], cwd=root,
                    package="m04-io-uring-deny-probe", version="1",
                )

            event_dirs = [path for path in (root / capture.CAPTURE_DIR / "events").iterdir()
                          if path.is_dir() and path.name not in prior_event_ids]
            self.assertEqual(len(event_dirs), 1, "denied syscall must leave exactly one event directory")
            denied_event_path = event_dirs[0] / "event.json"
            self.assertTrue(denied_event_path.is_file(), str(caught.exception))
            denied = json.loads(denied_event_path.read_text(encoding="utf-8"))
            self._assert_persisted_event(root, denied, denied_event_path)
            self.assertEqual(denied["exit_status"], 0, "probe command should observe EPERM and exit 0")
            self.assertTrue(any("io_uring_setup observed" in item
                                for item in denied["observation_violations"]))
            self.assertEqual(denied["changed_paths"], [])
            stdout = (root / denied["artifacts"]["stdout"]["path"]).read_text(encoding="utf-8")
            self.assertRegex(stdout, r'"errno"\s*:\s*1\b')
            trace = (root / denied["artifacts"]["strace"]["path"]).read_text(encoding="utf-8")
            self.assertRegex(trace, r"io_uring_setup\(.*\)\s+= -1 EPERM(?: \(.*\))?")

    def _assert_persisted_event(self, root: Path, event: dict, event_path: Path) -> None:
        self.assertTrue(event_path.is_file())
        on_disk = json.loads(event_path.read_text(encoding="utf-8"))
        self.assertEqual(on_disk["event_id"], event["event_id"])
        manifest = event.get("event_manifest")
        if manifest is not None:  # capture_install returns this; persisted JSON predates it.
            self.assertEqual(manifest["sha256"], hashlib.sha256(event_path.read_bytes()).hexdigest())
        for artifact in event["artifacts"].values():
            path = root / artifact["path"]
            self.assertTrue(path.is_file(), artifact["path"])
            data = path.read_bytes()
            self.assertEqual(len(data), artifact["size"], artifact["path"])
            self.assertEqual(hashlib.sha256(data).hexdigest(), artifact["sha256"], artifact["path"])


if __name__ == "__main__":
    unittest.main()
