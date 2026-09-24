"""Fixture-only tests for the Linux M04 install-event capture runner."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "capture-m04-install-event.py"
SPEC = importlib.util.spec_from_file_location("m04_install_capture", SCRIPT)
capture = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(capture)


class Fixture:
    def __init__(self):
        self.temp = tempfile.TemporaryDirectory(prefix="m04-event-fixture-")
        self.root = Path(self.temp.name)
        (self.root / capture.MARKER).write_text(capture.MARKER_TEXT, encoding="utf-8")

    def close(self):
        self.temp.cleanup()


class InstallEventCaptureTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.which = mock.patch.object(capture.shutil, "which", side_effect=lambda name: f"/usr/bin/{name}")
        self.which.start()
        self.platform = mock.patch.object(capture.sys, "platform", "linux")
        self.platform.start()
        self.execute = mock.patch.object(capture, "_execute", side_effect=self.fake_execute)
        self.execute_mock = self.execute.start()

    def tearDown(self):
        mock.patch.stopall()
        self.fx.close()

    def fake_execute(self, argv, cwd, env, root, trace_path, strace, bwrap, stdout_path, stderr_path):
        action = argv[-1]
        (root / "usr/bin").mkdir(parents=True, exist_ok=True)
        trace_path.write_text("", encoding="utf-8")
        stdout_path.write_bytes(b"install stdout\n")
        stderr_path.write_bytes(b"install stderr\n")
        if action == "write":
            (root / "usr/bin/new-tool").write_bytes(b"new payload")
            trace_path.write_text(f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/new-tool"))}, O_WRONLY|O_CREAT, 0644) = 3\n', encoding="utf-8")
            return 0
        if action == "replace-delete":
            (root / "usr/bin/existing").write_bytes(b"after")
            (root / "usr/bin/gone").unlink()
            trace_path.write_text(
                f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/existing"))}, O_WRONLY, 0644) = 3\n'
                f'unlink({json.dumps(str(root / "usr/bin/gone"))}) = 0\n', encoding="utf-8")
            return 0
        if action == "fail":
            (root / "usr/bin/partial").write_bytes(b"partial")
            trace_path.write_text(f'openat(AT_FDCWD, {json.dumps(str(root / "usr/bin/partial"))}, O_WRONLY, 0644) = 3\n', encoding="utf-8")
            return 7
        if action == "outside":
            outside = str(Path(root.anchor) / "etc/passwd")
            trace_path.write_text(f'unlink({json.dumps(outside)}) = -1 EROFS (Read-only file system)\n', encoding="utf-8")
            return 1
        raise AssertionError(action)

    def test_install_write_records_command_environment_logs_trace_and_snapshots(self):
        recipe = self.fx.root / "recipe.sh"
        recipe.write_text("make install DESTDIR=/fixture\n", encoding="utf-8")
        event = capture.capture_install(self.fx.root, ["make", "install", "write"],
                                        cwd=self.fx.root, env_overrides={"DESTDIR": "/fixture"},
                                        input_paths=[recipe], package="demo", version="1.2")
        self.assertEqual(event["argv"], ["make", "install", "write"])
        self.assertEqual(event["environment"]["DESTDIR"], "/fixture")
        self.assertEqual(event["exit_status"], 0)
        self.assertTrue(event["environment"]["HOME"].startswith(str(self.fx.root / capture.CAPTURE_DIR / "work")))
        self.assertTrue(event["environment"]["TMPDIR"].startswith(str(self.fx.root / capture.CAPTURE_DIR / "work")))
        self.assertNotIn("/events/", event["environment"]["HOME"].replace("\\", "/"))
        self.assertEqual(event["changed_paths"], ["/usr", "/usr/bin", "/usr/bin/new-tool"])
        self.assertEqual(len(event["inputs"]), 1)
        artifact_dir = self.fx.root / event["artifacts"]["strace"]["path"]
        self.assertIn("new-tool", artifact_dir.read_text(encoding="utf-8"))
        self.assertEqual(event["artifacts"]["stdout"]["sha256"], capture._sha256(
            self.fx.root / event["artifacts"]["stdout"]["path"]))
        self.assertTrue((self.fx.root / event["artifacts"]["before_snapshot"]["path"]).is_file())
        self.assertTrue((self.fx.root / event["artifacts"]["after_snapshot"]["path"]).is_file())

    def test_overwrite_and_delete_are_visible_in_before_after_diff(self):
        (self.fx.root / "usr/bin").mkdir(parents=True)
        (self.fx.root / "usr/bin/existing").write_bytes(b"before")
        (self.fx.root / "usr/bin/gone").write_bytes(b"remove me")
        event = capture.capture_install(self.fx.root, ["installer", "replace-delete"], cwd=self.fx.root)
        self.assertEqual(event["changed_paths"], ["/usr/bin/existing", "/usr/bin/gone"])
        before = json.loads((self.fx.root / event["artifacts"]["before_snapshot"]["path"]).read_text())
        after = json.loads((self.fx.root / event["artifacts"]["after_snapshot"]["path"]).read_text())
        self.assertNotEqual(before["entries"]["/usr/bin/existing"]["sha256"],
                            after["entries"]["/usr/bin/existing"]["sha256"])
        self.assertIn("/usr/bin/gone", before["entries"])
        self.assertNotIn("/usr/bin/gone", after["entries"])

    def test_nonzero_exit_keeps_complete_failure_evidence(self):
        with self.assertRaises(capture.InstallCommandFailed) as raised:
            capture.capture_install(self.fx.root, ["installer", "fail"], cwd=self.fx.root)
        event = raised.exception.event
        self.assertEqual(event["exit_status"], 7)
        self.assertIn("/usr/bin/partial", event["changed_paths"])
        self.assertTrue((self.fx.root / event["artifacts"]["stderr"]["path"]).is_file())

    def test_outside_root_write_attempt_is_rejected_and_recorded(self):
        with self.assertRaisesRegex(capture.CaptureError, "outside the fixture"):
            capture.capture_install(self.fx.root, ["installer", "outside"], cwd=self.fx.root)
        event_files = list((self.fx.root / capture.CAPTURE_DIR / "events").glob("*/event.json"))
        self.assertEqual(len(event_files), 1)
        event = json.loads(event_files[0].read_text(encoding="utf-8"))
        self.assertTrue(event["outside_root_write_attempts"])
        self.assertRegex(event["outside_root_write_attempts"][0], r"etc[\\/]passwd")

    def test_missing_strace_refuses_before_running_command(self):
        with mock.patch.object(capture.shutil, "which", side_effect=lambda name: None if name == "strace" else "/usr/bin/bwrap"):
            with self.assertRaisesRegex(capture.CaptureError, "strace is required"):
                capture.capture_install(self.fx.root, ["installer", "write"], cwd=self.fx.root)
        self.execute_mock.assert_not_called()

    def test_bwrap_mounts_host_readonly_fixture_writable_and_evidence_readonly(self):
        self.execute.stop()
        event_store = self.fx.root / capture.CAPTURE_DIR / "events"
        event_store.mkdir(parents=True)
        trace = self.fx.root / "trace.log"
        stdout, stderr = self.fx.root / "stdout.log", self.fx.root / "stderr.log"
        with mock.patch.object(capture.subprocess, "run", return_value=SimpleNamespace(returncode=0)) as run:
            status = capture._execute(["installer"], self.fx.root, {}, self.fx.root,
                                      trace, "/usr/bin/strace", "/usr/bin/bwrap", stdout, stderr)
        self.assertEqual(status, 0)
        argv = run.call_args.args[0]
        self.assertLess(argv.index("--ro-bind"), argv.index("--bind"))
        read_only = [index for index, arg in enumerate(argv) if arg == "--ro-bind"]
        self.assertGreater(read_only[1], argv.index("--bind"))
        self.assertIn(str(event_store), argv)
        self.assertEqual(argv.count("--ro-bind"), 2)
        self.assertEqual(argv.count("--bind"), 1)

    def test_snapshot_rejects_symlink_target_escape(self):
        link = self.fx.root / "escape"
        try:
            link.symlink_to("../../outside", target_is_directory=False)
        except (OSError, NotImplementedError) as exc:
            self.skipTest(f"symlink creation is unavailable: {exc}")
        with self.assertRaisesRegex(capture.CaptureError, "symlink target escapes"):
            capture._snapshot(self.fx.root)


if __name__ == "__main__":
    unittest.main()
